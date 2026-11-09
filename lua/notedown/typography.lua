-- Typographic punctuation in rendered markdown, drawn over what was typed,
-- which stays plain in the file:
--
--   --            ——   a dash
--   "x" 'x' it's  “x” ‘x’ it’s
--   1/2 15/16     ¹⁄₂ ¹⁵⁄₁₆
--   (c) 2026      ©    (only before a year, so lists of (a), (b), (c) stay)
--   Acme(r)       ®    (only right after a word)
--   (tm)          ™
--
-- Everything is drawn in exactly the columns the typed text takes: hiding
-- characters would leave nvim wrapping the line as if they were still there,
-- putting justified lines out of line. So the dash is two em dashes joined
-- into one long one, © sits centered in its parentheses' room, and ® and ™
-- sit right against the word they belong to.
-- The line under the cursor shows what was typed.
--
-- Not in code (fenced, inline, or >> code blocks), math, "---" and longer runs,
-- table borders, HTML, the marks of a --strikethrough-- (markdown.lua), or
-- what looks like an option ("--help": "--" after a
-- space or the line start and right before a letter or digit). Called by
-- render.lua on every render.

local M = {}

local SUPERSCRIPT = { "⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹" }
local SUBSCRIPT = { "₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉" }

-- Byte ranges of `code`, $math$ and <html> in a line, to leave alone.
local function protected(line)
  local ranges = {}
  for _, pattern in ipairs({ "()`+.-`+()", "()%$.-%$()", "()<[%a/!][^>]*>()" }) do
    for from, to in line:gmatch(pattern) do ranges[#ranges + 1] = { from, to - 1 } end
  end
  return ranges
end

local function inside(ranges, pos)
  for _, range in ipairs(ranges) do
    if pos >= range[1] and pos <= range[2] then return true end
  end
  return false
end

local function digits(number, table_)
  return (number:gsub("%d", function(d) return table_[tonumber(d) + 1] end))
end

-- The replacements in one line: { byte (1-based), bytes covered, text }.
local function replacements(line)
  local ranges = protected(line)
  local out = {}
  local function put(pos, len, text)
    if not inside(ranges, pos) then out[#out + 1] = { pos, len, text } end
  end

  -- Dashes.
  local struck = {}
  for _, strike in ipairs(require("notedown.markdown").strikes(line)) do
    struck[strike[1]], struck[strike[2] - 2] = true, true
  end
  local start = 1
  while true do
    local pos = line:find("--", start, true)
    if not pos then break end
    local before, after = line:sub(pos - 1, pos - 1), line:sub(pos + 2, pos + 2)
    if before ~= "-" and after ~= "-" and after ~= ">"
        and not (before == "!" and line:sub(pos - 2, pos - 2) == "<")
        and not ((pos == 1 or before:match("%s")) and after:match("%w"))
        and not struck[pos] then
      put(pos, 2, "——")
    end
    start = pos + 2
    while line:sub(start, start) == "-" do start = start + 1 end
  end

  -- Quotes: opening after the line start, a space, an opening bracket or a
  -- dash; an apostrophe between letters; closing otherwise. A ' right before a
  -- digit after a space ('90s) is an apostrophe too.
  for pos, char in line:gmatch("()([\"'])") do
    local before, after = line:sub(pos - 1, pos - 1), line:sub(pos + 1, pos + 1)
    local opens = pos == 1 or before:match("[%s%(%[{—%-]") ~= nil
    local text
    if char == '"' then
      text = opens and "“" or "”"
    elseif before:match("%w") and after:match("%w") then
      text = "’"
    elseif opens and after:match("%d") then
      text = "’"
    else
      text = opens and "‘" or "’"
    end
    put(pos, 1, text)
  end

  -- Fractions: digits/digits on their own, not a date (11/08/2026) or a path.
  for pos, num, den in line:gmatch("()(%d+)/(%d+)") do
    local before = line:sub(pos - 1, pos - 1)
    local after = line:sub(pos + #num + 1 + #den, pos + #num + 1 + #den)
    if not before:match("[%w/.]") and not after:match("[%w/]") and not (after == "." and
        line:sub(pos + #num + #den + 2, pos + #num + #den + 2):match("%d")) then
      put(pos, #num + 1 + #den, digits(num, SUPERSCRIPT) .. "⁄" .. digits(den, SUBSCRIPT))
    end
  end

  -- Symbols: © centered in the room its letters took; ® and ™ against the word.
  for pos in line:gmatch("()%([cC]%)") do
    if line:sub(pos + 3):match("^%s*%d") then put(pos, 3, " © ") end
  end
  for pos in line:gmatch("()%([rR]%)") do
    if line:sub(pos - 1, pos - 1):match("%w") then put(pos, 3, "®  ") end
  end
  for pos in line:gmatch("()%([tT][mM]%)") do put(pos, 4, "™   ") end

  return out
end

-- The text with the same replacements, for drawing elsewhere (heading images,
-- which can use a one-column dash).
function M.smarten(text)
  local list = replacements(text)
  table.sort(list, function(a, b) return a[1] > b[1] end)
  for _, r in ipairs(list) do
    local replacement = r[3] == "——" and "—" or vim.trim(r[3])
    text = text:sub(1, r[1] - 1) .. replacement .. text:sub(r[1] + r[2])
  end
  return text
end

-- Marks for render.lua. Not in fences or lines that aren't markdown (scan,
-- blocks.lua).
function M.marks(scan, add)
  for i, line in ipairs(scan.lines) do
    local row = i - 1
    if not scan.fenced[row] and not scan.verbatim[row] and line:find("[%-\"'/%(]")
        and not line:match("^[%s|:%-]+$") and not line:match("^    ") then
      for _, r in ipairs(replacements(line)) do
        add(row, r[1] - 1, true, {
          end_col = r[1] - 1 + r[2],
          virt_text = { { r[3] } },
          virt_text_pos = "overlay",
          hl_mode = "combine",
        })
      end
    end
  end
end

return M
