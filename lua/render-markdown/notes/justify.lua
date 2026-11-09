-- Justified paragraphs in rendered markdown, as in a newspaper: a wrapped line
-- that's at least THRESHOLD full is stretched to the window's right edge by
-- spreading extra spaces between its words. Emptier lines than that are left
-- alone, so gaps stay small.
--
-- Where lines break is chosen for the whole paragraph at once, the way TeX
-- does (Knuth and Plass): of all the ways to break it, the one whose lines are
-- most evenly full, so one line taking a word early can spare another a wide
-- gap. A paragraph never ends with one word alone on its last line when moving
-- a second word down can avoid it.
--
-- Nvim can't justify, so this plans where each line breaks and puts the extra
-- spaces in as virtual text. Every planned line, stretched or not, is made
-- exactly one column short of the window, so nvim's word wrap ('linebreak')
-- breaks exactly there: the space after the last word takes the last column.
-- That keeps the plan right without measuring the screen.
--
-- Only plain paragraphs, in >> note blocks too: not lists, quotes, headings,
-- tables, indented lines, >> code, latex or mermaid blocks, and not lines with
-- markup whose rendered width differs from its text (emphasis, code, links,
-- math, ==highlights==, HTML). The line under the cursor shows as typed.
-- Called from notes/blocks.lua on every render.

local M = {}

M.THRESHOLD = 0.8

-- Characters render-markdown hides or replaces, or that start markdown blocks.
local MARKUP = "[%*_`%[%]%$<>|\\~\t]"

local function eligible(line)
  return line:match("^%S") ~= nil
    and not line:match("^[-*+]%s") and not line:match("^%d+[.)]%s")
    and not line:match("^#") and not line:match("^>")
    and not line:find(MARKUP) and not line:find("==", 1, true)
end

-- The line as tokens nvim may break after: a word up to a space, or up to a
-- 'breakat' character followed by a non-'breakat' one (nvim can break after
-- the "-" in "machine-language"). Each has its width, the spaces after it,
-- and the byte where those spaces start.
local function tokens(line)
  local breakat = vim.o.breakat
  local function is_break(char) return char ~= "" and breakat:find(char, 1, true) ~= nil end
  local list = {}
  local chars = vim.fn.split(line, [[\zs]])
  local byte = 0
  local text = ""
  for index, char in ipairs(chars) do
    local next_char = chars[index + 1] or ""
    if char == " " then
      if text ~= "" then
        list[#list + 1] = { w = vim.fn.strdisplaywidth(text), gap = 0, gap_byte = byte }
        text = ""
      end
      local last = list[#list]
      if last then last.gap = last.gap + 1 end
    else
      text = text .. char
      if is_break(char) and next_char ~= " " and next_char ~= "" and not is_break(next_char) then
        list[#list + 1] = { w = vim.fn.strdisplaywidth(text), gap = 0, gap_byte = byte + #char }
        text = ""
      end
    end
    byte = byte + #char
  end
  if text ~= "" then list[#list + 1] = { w = vim.fn.strdisplaywidth(text), gap = 0, gap_byte = byte } end
  return list
end

-- Cost of a line break plan, per line: how unevenly full it is. A line's
-- spare columns, shared out over its gaps, squared, so one wide gap costs more
-- than several narrow ones. A line with no gap to stretch costs more again.
local WIDOW = 1000 -- a last line of one word, when the paragraph has more
local function line_cost(used, gaps, fit, last, words, total)
  if last then return (words == 1 and total > 1) and WIDOW or 0 end
  local spare = fit - used
  if gaps == 0 then return 3 * spare * spare end
  return spare * spare / gaps
end

-- The paragraph's tokens split into lines: the plan with the lowest total cost
-- among all whose lines fit in fit columns.
local function break_lines(list, fit)
  local n = #list
  local best, from = { [0] = 0 }, {}
  for j = 1, n do
    best[j] = math.huge
    local used, gaps = 0, 0
    for i = j, 1, -1 do
      -- The line list[i..j]: its width, without the spaces after its last token.
      used = used + list[i].w
      if i < j then
        used = used + list[i].gap
        if list[i].gap > 0 then gaps = gaps + 1 end
      end
      if used > fit and i < j then break end -- a lone over-long word still gets a line
      local cost = best[i - 1] + line_cost(used, gaps, fit, j == n, j - i + 1, n)
      if cost < best[j] then
        best[j], from[j] = cost, i
      end
    end
  end
  local lines, j = {}, n
  while j > 0 do
    table.insert(lines, 1, vim.list_slice(list, from[j], j))
    j = from[j] - 1
  end
  return lines
end

-- Extra spaces for one line: { byte, count } pairs.
local function plan(line, width)
  local fit = width - 1
  local lines = break_lines(tokens(line), fit)
  if #lines < 2 then return {} end

  local extra = {}
  for n, toks in ipairs(lines) do
    local last_line = n == #lines
    local used, gaps = 0, {}
    for k, token in ipairs(toks) do
      used = used + token.w
      if k < #toks then
        used = used + token.gap
        if token.gap > 0 then gaps[#gaps + 1] = token end
      end
    end
    local tail = toks[#toks]
    -- Every line ends a column short of the window, the same column even when
    -- it breaks inside a word (after a "-"), with no space after it.
    local missing = fit - used
    if missing > 0 then
      if #gaps > 0 and used / fit >= M.THRESHOLD then
        -- Spread evenly along the line, not bunched at its start.
        for k, token in ipairs(gaps) do
          local count = math.floor(k * missing / #gaps + 0.5) - math.floor((k - 1) * missing / #gaps + 0.5)
          if count > 0 then extra[#extra + 1] = { token.gap_byte, count } end
        end
      elseif not last_line then
        -- Too short to stretch: fill the end with spaces, so the line still
        -- breaks where planned.
        extra[#extra + 1] = { tail.gap_byte, missing }
      end
    end
  end
  return extra
end

-- Marks for render-markdown. skip has the 0-based rows not to touch; indent
-- has rows whose text starts that many columns in on every screen line (2 for
-- a line in a >> note block, after its bar); bg has the background highlight
-- of rows that have one (a note block's tint), for the added spaces.
function M.marks(buf, lines, skip, indent, bg, add)
  local win = require("render-markdown.notes.window")(buf)
  if not win or not vim.wo[win].wrap or not vim.wo[win].linebreak then return end
  local info = vim.fn.getwininfo(win)[1]
  local width = info.width - info.textoff
  if width < 20 then return end

  local fence
  for i, line in ipairs(lines) do
    local row = i - 1
    local marker = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if marker then
      if not fence then
        fence = marker
      elseif marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        fence = nil
      end
    elseif not fence and not skip[row] and eligible(line)
        and vim.fn.strdisplaywidth(line) > width - (indent[row] or 0) - 1 then
      for _, space in ipairs(plan(line, width - (indent[row] or 0))) do
        add(row, space[1], true, {
          virt_text = { { (" "):rep(space[2]), bg[row] } },
          virt_text_pos = "inline",
        })
      end
    end
  end
end

return M
