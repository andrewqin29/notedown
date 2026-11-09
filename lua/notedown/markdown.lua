-- The markdown notedown draws, found in nvim's tree-sitter parse of the note:
--
--   # headings   the #s hidden; from ### down, a bar in the heading's color
--                across the window (# and ## are images, heading_images.lua)
--   - lists      a bullet by how deeply the list is nested, and the list moved
--                in from the text around it; 1. 1. 1. numbered 1. 2. 3.
--   - [ ] tasks  the checkbox as an icon, in place of the bullet
--   > quotes     a bar for each >, on wrapped lines too
--   ---          a line across the window
--   ==text==     highlighted
--   --text--     struck through: the -- right against the text, so "a -- b"
--                stays two dashes (typography.lua) and --help an option
--
-- None of it in >> blocks that aren't markdown (code, latex, mermaid) or on a
-- block's >> and << lines, and no headings in callouts (blocks.lua). In a
-- boxed block only what keeps the text's width: a heading is its text in the
-- heading's color, and there are no lists, quotes or lines. Called by
-- render.lua on every render.

local M = {}

-- By nesting level, cycling: medium dots (Nerd Font octicons dot-fill and
-- dot), then medium squares (Material Design), each one column wide.
local BULLETS = { "\u{f444}", "\u{f4c3}", "\u{f0a13}", "\u{f0a14}" }
-- Columns a list is moved in from the text around it.
local LIST_INDENT = "  "
local UNCHECKED = { "󰄱 ", "NotedownUnchecked" }
local CHECKED = { "󰱒 ", "NotedownChecked" }
local QUOTE = "▋"
local DASH = "─"
-- The bar behind a heading, by level. None for # and ##, which are images.
local HEADING_BARS = { [3] = "NotedownH3Bg", [4] = "NotedownH4Bg", [5] = "NotedownH5Bg", [6] = "NotedownH6Bg" }

local queries = {}
local function query(lang, source)
  queries[source] = queries[source] or vim.treesitter.query.parse(lang, source)
  return queries[source]
end

local BLOCK_QUERY = [[
  (atx_heading) @heading
  (list_item) @item
  (block_quote_marker) @quote
  (block_continuation) @continuation
  (thematic_break) @dash
]]
local INLINE_QUERY = [[(inline) @inline]]

-- How many of node and its ancestors are of the type, and the outermost one.
local function nesting(node, type)
  local count, outermost = 0, nil
  while node and node:type() ~= "document" do
    if node:type() == type then
      count, outermost = count + 1, node
    end
    node = node:parent()
  end
  return count, outermost
end

local function heading(node, add)
  local marker = node:named_child(0)
  if not marker then return end
  local row, col, _, end_col = marker:range()
  -- the #s and the space after them
  add(row, col, true, { end_col = end_col + 1, conceal = "" })
  local bar = HEADING_BARS[end_col - col]
  if bar then add(row, 0, true, { line_hl_group = bar }) end
end

-- A heading in a boxed block: the #s and the space after them hidden, and
-- its text in the heading's color, over the box's own text color.
local function boxed_heading(buf, node, add)
  local marker = node:named_child(0)
  if not marker then return end
  local row, col, _, end_col = marker:range()
  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  add(row, col, true, { end_col = end_col + 1, conceal = "" })
  add(row, end_col, false, { end_col = #line, hl_group = "NotedownH" .. (end_col - col), priority = 201 })
end

-- The list item's position among the items before it.
local function position(item)
  local count = 0
  while item and item:type() == "list_item" do
    count, item = count + 1, item:prev_sibling()
  end
  return count
end

-- The last row of the item that its list's indent goes on (exclusive): up to
-- a list inside it, and not a blank line ending the whole list.
local function indent_end(buf, item, list)
  for child in item:iter_children() do
    if child:type() == "list" then return (child:range()) end
  end
  local _, _, end_row = item:range()
  local list_start, _, list_end = list:range()
  local last = list_end - (list_end == list_start and 0 or 1)
  local line = vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1] or ""
  if list_end == end_row and line == "" then return end_row - 1 end
  return end_row
end

local function bullet(buf, item, marker, add)
  local level, list = nesting(item, "list")
  local text = vim.treesitter.get_node_text(marker, buf)
  local icon
  if marker:type() == "list_marker_dot" or marker:type() == "list_marker_parenthesis" then
    -- the number as written, or the item's position for lists of 1. 1. 1.
    local number = tonumber(vim.trim(text):sub(1, -2)) or 0
    icon = (number > 1 and number or position(item)) .. "."
  else
    icon = BULLETS[(level - 1) % #BULLETS + 1]
  end
  -- (a marker can start with the indent before it: tree-sitter-markdown#127)
  local shown = text:match("^%s*") .. icon
  local wider = vim.api.nvim_strwidth(shown) > vim.api.nvim_strwidth(text)
  local row, col, end_row, end_col = marker:range()
  add(row, col, true, {
    end_row = end_row,
    end_col = end_col,
    virt_text = { { shown, "NotedownBullet" } },
    virt_text_pos = wider and "inline" or "overlay",
    conceal = wider and "" or nil,
  })

  local start = item:range()
  local _, list_col = list:range()
  for r = start, indent_end(buf, item, list) - 1 do
    add(r, list_col, false, { virt_text = { { LIST_INDENT } }, virt_text_pos = "inline", priority = 100 })
  end
end

-- The bullet hidden and "[ ] " drawn as the list's indent and the icon, then
-- one more column, so the text starts as far in as after a bullet.
local function checkbox(buf, marker, box, add)
  local text = vim.treesitter.get_node_text(marker, buf)
  local row, col, end_row, end_col = marker:range()
  add(row, col + #text:match("^%s*"), true, { end_row = end_row, end_col = end_col, conceal = "" })
  local icon = box:type() == "task_list_marker_checked" and CHECKED or UNCHECKED
  local box_row, box_col, _, box_end = box:range()
  add(box_row, box_col, true, {
    virt_text = { { LIST_INDENT }, icon },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
  add(box_row, box_end + 1, true, { virt_text = { { " " } }, virt_text_pos = "inline", hl_mode = "combine" })
end

local function list_item(buf, item, add)
  local marker = item:named_child(0)
  if not marker or not marker:type():find("^list_marker") then return end
  local box = marker:next_named_sibling()
  local _, _, _, marker_end = marker:range()
  if box and box:type():find("^task_list_marker") and select(2, box:range()) == marker_end then
    checkbox(buf, marker, box, add)
  else
    bullet(buf, item, marker, add)
  end
end

-- A bar over each > of the quote markers in node, as many as the quotes it's
-- in: a marker is one >, a continuation line's start has one per quote.
local function quote(buf, node, add)
  local row, col = node:range()
  local depth = nesting(node, "block_quote")
  local text = vim.treesitter.get_node_text(node, buf)
  local n = 0
  for at in text:gmatch("()>") do
    n = n + 1
    if n > depth then break end
    add(row, col + at - 1, true, {
      end_col = col + at,
      virt_text = { { QUOTE, "NotedownQuote" } },
      virt_text_pos = "overlay",
      virt_text_repeat_linebreak = true,
    })
  end
end

-- Row and column of a byte offset in a node's text.
local function locate(start_row, start_col, text, offset)
  local before = text:sub(1, offset)
  local _, newlines = before:gsub("\n", "")
  if newlines == 0 then return start_row, start_col + offset end
  return start_row + newlines, #before:match("[^\n]*$")
end

-- Each --text-- in the text, as { from, to }: the bytes (1-based) where its
-- opening -- starts and after its closing -- ends. Like markdown's emphasis,
-- the opening -- is right before the text and not after a letter or digit,
-- the closing one right after the text and not before one, and the text has no
-- -- in it; all on one line. So "cup--or", "a -- b" and "--help" are left
-- alone (typography.lua draws them as dashes, or leaves them).
function M.strikes(text)
  local list = {}
  local start = 1
  while true do
    local from = text:find("%-%-[^%s%-]", start)
    if not from then break end
    start = from + 2
    if not text:sub(from - 1, from - 1):match("[%w%-]") then
      local close = text:find("--", from + 2, true)
      if close and not text:sub(from, close):find("\n")
          and not text:sub(close - 1, close - 1):match("%s")
          and not text:sub(close + 2, close + 2):match("[%w%-]") then
        list[#list + 1] = { from, close + 2 }
        start = close + 2
      end
    end
  end
  return list
end

-- ==highlights== and --strikethroughs--: the marks hidden, the text colored.
local function inline_marks(buf, scan, node, add)
  local text = vim.treesitter.get_node_text(node, buf)
  local start_row, start_col = node:range()
  local function top_level(row, col)
    local at = vim.treesitter.get_node({ bufnr = buf, pos = { row, col }, ignore_injections = false })
    return at and at:type() == "inline"
  end
  local function mark(from, to, group)
    local row, col = locate(start_row, start_col, text, from - 1)
    local end_row, end_col = locate(start_row, start_col, text, to - 1)
    if not scan.verbatim[row] and not scan.verbatim[end_row] and top_level(row, col) and top_level(end_row, end_col) then
      add(row, col, true, { end_col = col + 2, conceal = "" })
      add(end_row, end_col - 2, true, { end_col = end_col, conceal = "" })
      add(row, col, false, { end_row = end_row, end_col = end_col, hl_group = group })
    end
  end
  for from, to in text:gmatch("()==[^=]+==()") do mark(from, to, "NotedownHighlight") end
  for _, strike in ipairs(M.strikes(text)) do mark(strike[1], strike[2], "NotedownStrikethrough") end
end

function M.marks(buf, scan, add)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
  if not ok or not parser then return end
  parser:parse(true)
  parser:for_each_tree(function(tree, language_tree)
    local lang = language_tree:lang()
    if lang == "markdown" then
      local q = query("markdown", BLOCK_QUERY)
      for id, node in q:iter_captures(tree:root(), buf) do
        local capture, row = q.captures[id], node:range()
        if node:has_error() then
          -- (left as typed)
        elseif capture == "heading" then
          if scan.box[row] then
            boxed_heading(buf, node, add)
          elseif not scan.block[row] then
            heading(node, add)
          end
        elseif not scan.verbatim[row] and not scan.box[row] then
          if capture == "item" then
            list_item(buf, node, add)
          elseif capture == "quote" or capture == "continuation" then
            quote(buf, node, add)
          elseif capture == "dash" then
            add(row, 0, true, { virt_text = { { DASH:rep(vim.o.columns), "NotedownDash" } }, virt_text_pos = "overlay" })
          end
        end
      end
    elseif lang == "markdown_inline" then
      local q = query("markdown_inline", INLINE_QUERY)
      for _, node in q:iter_captures(tree:root(), buf) do
        -- (each mark checks its own rows: a paragraph can start on a block's <<)
        if not node:has_error() then inline_marks(buf, scan, node, add) end
      end
    end
  end)
end

return M
