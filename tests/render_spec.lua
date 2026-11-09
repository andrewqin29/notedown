-- Drawing notes (render.lua, markdown.lua, blocks.lua): snapshots of the
-- fixtures in tests/fixtures as drawn, and how the drawing follows the
-- cursor, the mode and the window.
local t = require("tests.t")
local render = require("notedown.render")

local DOT = "\u{f444}" -- the first level's bullet

local function fixture(name)
  return vim.fn.readfile(t.root .. "/tests/fixtures/" .. name .. ".md")
end

local function drawn(buf)
  return table.concat(t.body(), "\n") .. "\n\n-- marks\n" .. table.concat(t.marks(buf), "\n")
end

for _, name in ipairs({ "markdown", "blocks", "prose" }) do
  t.test("snapshot: " .. name, function()
    vim.o.lines = 100
    local buf = t.open(fixture(name), name)
    t.snapshot(name, drawn(buf))
  end)
end

t.test("snapshot: blocks in a 40-column window", function()
  vim.o.lines = 100
  local buf = t.open(fixture("blocks"), "blocks")
  vim.cmd("vsplit")
  vim.cmd("vertical resize 40")
  t.settle()
  t.snapshot("blocks-narrow", table.concat(vim.tbl_map(function(line)
    return (vim.fn.strcharpart(line, 0, 40):gsub("%s+$", ""))
  end, t.body()), "\n") .. "\n\n-- marks\n" .. table.concat(t.marks(buf), "\n"))
end)

t.test("the cursor's line shows as typed", function()
  t.open({ "# Title", "- item", "> quote" })
  t.cursor(2)
  -- (the list's indent isn't the item's text, and stays)
  t.eq(vim.list_slice(t.body(), 1, 3), { "Title", "  - item", "▋ quote" })
  t.cursor(3)
  t.eq(vim.list_slice(t.body(), 1, 3), { "Title", "  " .. DOT .. " item", "> quote" })
end)

t.test("a block's lines show as typed while the cursor is in it", function()
  t.open({ ">> python", "x = 1", "<<" })
  t.eq(vim.list_slice(t.body(), 1, 2), { "  python", " x = 1" })
  t.cursor(2)
  t.eq(vim.list_slice(t.body(), 1, 3), { "  python", "x = 1", "<<" })
end)

t.test("a box stays square around formatted text, and with the cursor in it", function()
  t.open({ ">> boxed", "A *Tour* of _Systems_", "## A heading", "`code` and ==marked==", "<<" })
  local box = {
    "┌───────────────────────┐",
    "│ A Tour of Systems     │",
    "│ A heading             │",
    "│ code and marked       │",
    "└───────────────────────┘",
  }
  t.eq(vim.list_slice(t.body(), 1, 5), box)
  t.cursor(2)
  box[2] = "│ A *Tour* of _Systems_ │"
  t.eq(vim.list_slice(t.body(), 1, 5), box)
end)

t.test("a heading in a box: its text in the heading's color, no bar", function()
  local buf = t.open({ ">> boxed", "## A heading", "<<" })
  local marks = table.concat(t.marks(buf), "\n")
  t.ok(marks:find("hl NotedownH2", 1, true), marks)
  t.ok(not marks:find("line_hl", 1, true), marks)
end)

t.test("insert mode shows the note as typed, with the window's own options", function()
  local buf = t.open({ "# Title" })
  t.eq(vim.wo.conceallevel, 3)
  t.keys("i")
  t.settle()
  t.eq(#t.marks(buf), 0, "marks")
  t.eq(vim.wo.conceallevel, 0)
  t.keys("<Esc>")
  t.settle()
  t.ok(#t.marks(buf) > 0, "marks back")
  t.eq(vim.wo.conceallevel, 3)
end)

t.test(":Notedown turns rendering off and on", function()
  local buf = t.open({ "# Title" })
  vim.cmd("Notedown")
  t.settle()
  t.eq(#t.marks(buf), 0)
  t.eq(t.body()[1], "# Title")
  vim.cmd("Notedown")
  t.settle()
  t.eq(t.body()[1], "Title")
end)

t.test("reading mode renders the cursor's line too", function()
  local buf = t.open({ "# Title", "- item" })
  t.cursor(2)
  render.everywhere(buf, true)
  t.settle()
  t.eq(t.body()[2], "  " .. DOT .. " item")
  t.eq(vim.wo.concealcursor, "nc")
  render.everywhere(buf, false)
  t.settle()
  t.eq(t.body()[2], "  - item")
  t.eq(vim.wo.concealcursor, "")
end)

t.test("only markdown files: not other buffers holding markdown", function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Title", "" })
  vim.bo[buf].filetype = "markdown"
  t.settle()
  t.eq(#t.marks(buf), 0)
  t.eq(vim.wo.winbar, "", "no breadcrumb")
  t.eq(t.screen()[1], "# Title")
end)

t.test("a change is drawn, the last of several quick ones too", function()
  local buf = t.open({ "# Title" })
  for i = 1, 5 do
    vim.api.nvim_buf_set_lines(buf, i, i, false, { "- item " .. i })
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
  end
  vim.api.nvim_win_set_cursor(0, { 7, 0 })
  t.settle()
  local items = {}
  for i = 1, 5 do items[i] = "  " .. DOT .. " item " .. i end
  t.eq(vim.list_slice(t.body(), 2, 6), items)
end)

t.test("diff windows show the note as typed", function()
  local buf = t.open({ "# Title" })
  vim.cmd("diffthis")
  t.cursor(1)
  t.eq(#t.marks(buf), 0)
end)

t.test("a note opened again after its buffer is gone renders", function()
  t.open({ "# Title" })
  local path = vim.api.nvim_buf_get_name(0)
  vim.cmd("bwipeout!")
  vim.cmd.edit(path)
  t.cursor(2)
  t.eq(t.body()[1], "Title")
end)
