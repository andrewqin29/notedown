-- notedown's >> blocks. Callouts, without a > on every line:
--
--   >> note            (or tip, important, warning, caution)
--   hello
--   this is a note
--   <<
--
-- renders like GitHub's "> [!NOTE]" callout: a colored title line, then a bar
-- in front of every line of the block, wrapped lines included. Text after the
-- tag replaces the title (">> tip Keyboard shortcuts"). Tags are written in
-- lowercase; capitals work the same (">> NOTE").
--
--   >> latex
--   x^2 = y^3
--   \sum_{i=1}^{n} i \leq \frac{n^2}{2}
--   <<
--
-- shows the formulas typeset, one per line and centered, as an image made with
-- pdflatex by snacks.nvim's image module (images.lua). The LaTeX shows
-- while the cursor is in the block. A block that already starts with \begin
-- (aligned, cases, ...) is typeset as it is.
--
-- Where images can't be shown (a terminal without kitty's graphics protocol),
-- the block shows as typed, as a mermaid block does.
--
--   >> mermaid
--   graph LR
--     source --> compiler --> program
--   <<
--
-- shows the diagram as an image made by mermaid-cli (mmdc), sized and centered
-- like other images, in colors to match (assets/mermaid/config.json).
--
--   >> boxed
--   Chapter 1: A Tour of Computer Systems
--   <<
--
-- shows its lines in white inside a box drawn with line characters, as wide as
-- the longest line, with a column of room either side.
--
-- A block shows only once its << is there, and not inside fenced code blocks.
-- The marker lines of a callout show as typed while the cursor is on them. This
-- isn't markdown, so other markdown viewers (GitHub included) show the >> and
-- << lines as they are.

local M = {}

-- Each kind of block. Callouts have an icon and title, and are drawn in
-- their color (a diagnostic color) on a tint of it (highlights.lua defines fg
-- and bg).
M.kinds = {
  note      = { icon = "󰋽", title = "Note",      color = "DiagnosticInfo",  fg = "NotedownNote",      bg = "NotedownNoteBg" },
  tip       = { icon = "󰌶", title = "Tip",       color = "DiagnosticOk",    fg = "NotedownTip",       bg = "NotedownTipBg" },
  important = { icon = "󰅾", title = "Important", color = "DiagnosticHint",  fg = "NotedownImportant", bg = "NotedownImportantBg" },
  warning   = { icon = "󰀪", title = "Warning",   color = "DiagnosticWarn",  fg = "NotedownWarning",   bg = "NotedownWarningBg" },
  caution   = { icon = "󰳦", title = "Caution",   color = "DiagnosticError", fg = "NotedownCaution",   bg = "NotedownCautionBg" },
  latex     = { math = true },
  mermaid   = { chart = true },
  boxed     = { box = true },
}

-- Code blocks: ">> python" ... "<<" shows the code highlighted as that language
-- (with its tree-sitter parser), like a ```python block. Tag to parser name.
M.code = {
  python = "python", py = "python",
  c = "c",
  cpp = "cpp", ["c++"] = "cpp",
  java = "java",
  rust = "rust", rs = "rust",
  ocaml = "ocaml", ml = "ocaml",
}

local function kind_for(tag)
  if M.kinds[tag] then return M.kinds[tag] end
  if M.code[tag] then return { code = M.code[tag], name = tag } end
end

local BAR = "▋"

-- How far in a wrapped line continues while notedown renders, with
-- 'breakindentopt' list:-1 (render.lua): as many columns as
-- 'formatlistpat' matches at the start of the line. Each match below is as long
-- as the rendered prefix in front of the text, so wrapped lines continue under
-- the text. Lines that match nothing, like paragraphs, continue at the left.
--
--   "- [ ] x"  5: two columns of list indent, then the checkbox and a space
--   "- x"      4: the indent, then "● " (hence the 2 extra characters matched)
--   "1. x"     5: the indent, then "1. "
--   "> x"      2: the bar and a space, for each level of quote
M.list_pattern = table.concat({
  [=[^\s*[-*+]\s\+\[[ xX-]\]]=],
  [=[^\s*[-*+]\s\+\S.]=],
  [=[^\s*\d\+[.)]\s\+\S.]=],
  [=[^\%(>\s\?\)\+]=],
}, [[\|]])

-- Lines in a >> block have a bar in front that isn't in the text, so no pattern
-- can know to indent them. Instead, each render adds one alternative per line
-- in a block, matching that line's own start, 2 columns longer than usual.
local function set_list_pattern(buf, scan)
  local extra = {}
  for _, block in ipairs(scan.blocks) do
    for row = block.first + 1, block.last - 1 do
      local line = scan.lines[row + 1]
      if scan.note[row] and line:find("%S") then
        local match = vim.fn.matchstrpos(line, M.list_pattern)
        local width = 2 + (match[2] >= 0 and match[3] - match[2] or 0)
        local start = vim.fn.escape(vim.fn.strcharpart(line, 0, 40), [[\]])
        extra[#extra + 1] = [[^\%(\V]] .. start .. [[\m\)\@=]] .. ("."):rep(width)
      end
    end
  end
  extra[#extra + 1] = M.list_pattern
  local pattern = table.concat(extra, [[\|]])
  if vim.bo[buf].formatlistpat ~= pattern then vim.bo[buf].formatlistpat = pattern end
end

-- The note's >> blocks and ``` fences, read from its lines once per change:
--
--   lines     the buffer's lines
--   blocks    each block as { first, last, kind, title }, rows from 0
--   block     rows of a block, its >> and << lines included
--   verbatim  rows that aren't markdown: a block's >> and << lines, and the
--             lines of code, latex, mermaid and boxed blocks
--   note      rows inside a callout, to its kind
--   fenced    rows of ``` and ~~~ fences, delimiters included
--
-- A block shows only once its << is there, and not inside a fence. Inside a
-- block only its << counts, so code can contain ">> x" and ``` lines.
local scans = {}

function M.scan(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if scans[buf] and scans[buf].tick == tick then return scans[buf] end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local scan = { tick = tick, lines = lines, blocks = {}, block = {}, verbatim = {}, note = {}, fenced = {} }
  local open, fence
  for i, line in ipairs(lines) do
    local row = i - 1
    local marker = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if marker and not open then
      scan.fenced[row] = true
      if not fence then
        fence = marker
      elseif marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        fence = nil
      end
    elseif open then
      if line:match("^<<%s*$") then
        open.last = row
        scan.blocks[#scan.blocks + 1] = open
        open = nil
      end
    elseif fence then
      scan.fenced[row] = true
    else
      local tag, title = line:match("^>>%s*([%w%+#]+)%s*(.-)%s*$")
      local kind = tag and kind_for(tag:lower())
      if kind then open = { first = row, kind = kind, title = title } end
    end
  end
  for _, block in ipairs(scan.blocks) do
    local markdown = block.kind.icon ~= nil
    for row = block.first, block.last do
      scan.block[row] = true
      local inside = row > block.first and row < block.last
      if not (markdown and inside) then scan.verbatim[row] = true end
      if markdown and inside then scan.note[row] = block.kind end
    end
  end
  scans[buf] = scan
  return scan
end

vim.api.nvim_create_autocmd("BufWipeout", {
  group = vim.api.nvim_create_augroup("notedown.blocks", { clear = true }),
  callback = function(ev) scans[ev.buf] = nil end,
})

-- Highlighted code by language and text, so a render parses only code it
-- hasn't seen.
local highlighted_cache = {}

-- The code's lines as virtual lines: highlighted by the language's tree-sitter
-- highlights, on the code block background, padded to the longest line.
local function highlighted(code, lang)
  local text = table.concat(code, "\n")
  local key = lang .. "\0" .. text
  if highlighted_cache[key] then return highlighted_cache[key] end

  -- The highlight group at each byte, later (more specific) captures winning.
  local groups = {}
  for row = 1, #code do groups[row] = {} end
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, lang)
  local query = ok and vim.treesitter.query.get(lang, "highlights")
  if query then
    local tree = parser:parse()[1]
    for id, node in query:iter_captures(tree:root(), text) do
      local name = query.captures[id]
      if not name:find("^_") and name ~= "spell" and name ~= "nospell" and name ~= "conceal" then
        local group = "@" .. name .. "." .. lang
        local start_row, start_col, end_row, end_col = node:range()
        for row = start_row, math.min(end_row, #code - 1) do
          local from = row == start_row and start_col or 0
          local to = row == end_row and end_col or #code[row + 1]
          for col = from, to - 1 do groups[row + 1][col] = group end
        end
      end
    end
  end

  local tab = (" "):rep(vim.bo.tabstop)
  local width = 0
  for _, line in ipairs(code) do width = math.max(width, vim.api.nvim_strwidth((line:gsub("\t", tab)))) end

  local bg = "NotedownCode"
  local out = {}
  for row, line in ipairs(code) do
    local chunks = { { " ", bg } }
    local start = 0
    for col = 1, #line do
      if col == #line or groups[row][col] ~= groups[row][start] then
        local group = groups[row][start]
        chunks[#chunks + 1] = { line:sub(start + 1, col):gsub("\t", tab), group and { bg, group } or bg }
        start = col
      end
    end
    local shown = vim.api.nvim_strwidth((line:gsub("\t", tab)))
    chunks[#chunks + 1] = { (" "):rep(width - shown + 1), bg }
    out[row] = chunks
  end
  highlighted_cache[key] = out
  return out
end

-- Called by render.lua on every render.
function M.marks(buf, scan, add)
  local lines = scan.lines
  set_list_pattern(buf, scan)

  for _, block in ipairs(scan.blocks) do
    local kind = block.kind

    if kind.code then
      -- The >> line becomes a label (the language's icon and name), the code
      -- shows highlighted below it, and the code's own lines and the << are
      -- hidden. The code's lines come back while the cursor is in them; on
      -- the >> line it shows as typed.
      local ok, devicons = pcall(require, "nvim-web-devicons")
      local icon, icon_hl
      if ok then icon, icon_hl = devicons.get_icon_by_filetype(kind.code) end
      add(block.first, 0, true, {
        virt_text = { { (icon or " ") .. " ", icon_hl or "NotedownCodeLabel" } },
        virt_text_pos = "overlay",
      })
      add(block.first, 2, true, {
        end_col = #lines[block.first + 1],
        conceal = "",
        virt_text = { { kind.name, "NotedownCodeLabel" } },
        virt_text_pos = "inline",
      })
      local code = vim.list_slice(lines, block.first + 2, block.last)
      if #code > 0 then
        add(block.first, 0, true, { end_row = block.last, virt_lines = highlighted(code, kind.code) })
      end
      add(block.first + 1, 0, true, {
        end_row = block.last,
        end_col = #lines[block.last + 1],
        conceal_lines = "",
      })
    elseif kind.box then
      -- A box around the lines: the top border over the >> line, "│ " before
      -- each line and " │" after it (padded to the longest), and the bottom
      -- border over the <<. The >> and << lines show as typed while the cursor
      -- is on them.
      local width = vim.api.nvim_strwidth(lines[block.first + 1]) - 4
      for row = block.first + 1, block.last - 1 do
        width = math.max(width, vim.api.nvim_strwidth(lines[row + 1]))
      end
      local border = "NotedownBoxBorder"
      add(block.first, 0, true, {
        virt_text = { { "┌" .. ("─"):rep(width + 2) .. "┐", border } },
        virt_text_pos = "overlay",
      })
      for row = block.first + 1, block.last - 1 do
        local line = lines[row + 1]
        add(row, 0, false, {
          virt_text = { { "│ ", border } },
          virt_text_pos = "inline",
          right_gravity = false,
        })
        if #line > 0 then
          add(row, 0, false, { end_col = #line, hl_group = "NotedownBoxText", priority = 200 })
        end
        add(row, #line, false, {
          virt_text = { { (" "):rep(width - vim.api.nvim_strwidth(line) + 1) .. "│", border } },
          virt_text_pos = "inline",
        })
      end
      add(block.last, 0, true, {
        virt_text = { { "└" .. ("─"):rep(width + 2) .. "┘", border } },
        virt_text_pos = "overlay",
      })
    elseif kind.chart or kind.math then
      -- snacks draws the diagram or the typeset formulas over the block
      -- (images.lua); without images the source just shows.
    else
      local title = block.title ~= "" and block.title or kind.title
      -- The bar and title in the kind's color on its tint, which is behind the
      -- whole block: the title line and every line in it, wrapped ones too.
      local hl = kind.fg
      for row = block.first, block.last - 1 do
        add(row, 0, false, { line_hl_group = kind.bg })
      end

      -- Title line: a bar and a space over the >>, then the rest hidden and
      -- the icon and title shown there.
      add(block.first, 0, true, {
        virt_text = { { BAR .. " ", hl } },
        virt_text_pos = "overlay",
      })
      add(block.first, 2, true, {
        end_col = #lines[block.first + 1],
        conceal = "",
        virt_text = { { kind.icon .. " " .. title, hl } },
        virt_text_pos = "inline",
      })

      -- Every line in between: a bar pushes the text over, and a second bar at
      -- the window's left edge repeats on each wrapped line, which starts 2
      -- columns in (set_list_pattern). The first goes before a list's indent
      -- (markdown.lua), so a list in a block is indented within the block.
      for row = block.first + 1, block.last - 1 do
        add(row, 0, false, {
          virt_text = { { BAR .. " ", hl } },
          virt_text_pos = "inline",
          right_gravity = false,
          priority = 0,
        })
        add(row, 0, false, {
          virt_text = { { BAR, hl } },
          virt_text_win_col = 0,
          virt_text_repeat_linebreak = true,
        })
      end

      -- The << line takes no room.
      add(block.last, 0, true, { end_col = #lines[block.last + 1], conceal_lines = "" })
    end
  end
end

return M
