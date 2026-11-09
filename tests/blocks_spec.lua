-- Finding >> blocks and ``` fences (blocks.lua, scan).
local t = require("tests.t")
local blocks = require("notedown.blocks")

local function scan(lines) return blocks.scan(t.scratch(lines)) end

local function rows(set)
  local list = vim.tbl_keys(set)
  table.sort(list)
  return list
end

t.test("a callout, with the text after its tag as the title", function()
  local s = scan({ ">> tip Keyboard shortcuts", "Press gO", "<<" })
  t.eq(#s.blocks, 1)
  t.eq({ s.blocks[1].first, s.blocks[1].last, s.blocks[1].title }, { 0, 2, "Keyboard shortcuts" })
  t.eq(s.blocks[1].kind, blocks.kinds.tip)
end)

t.test("tags in capitals work the same", function()
  t.eq(scan({ ">> NOTE", "x", "<<" }).blocks[1].kind, blocks.kinds.note)
end)

t.test("code tags name the language's parser", function()
  local kind = scan({ ">> py", "x = 1", "<<" }).blocks[1].kind
  t.eq({ kind.code, kind.name }, { "python", "py" })
end)

t.test("an unknown tag is not a block", function()
  t.eq(#scan({ ">> nope", "x", "<<" }).blocks, 0)
end)

t.test("a block without its << is not a block", function()
  t.eq(#scan({ ">> note", "never closed" }).blocks, 0)
end)

t.test("no blocks inside a fence", function()
  local s = scan({ "```", ">> note", "x", "<<", "```", "after" })
  t.eq(#s.blocks, 0)
  t.eq(rows(s.fenced), { 0, 1, 2, 3, 4 })
end)

t.test("a fence inside a block is the block's text", function()
  local s = scan({ ">> python", "```", "x", "```", "<<", "```", "fenced" })
  t.eq(#s.blocks, 1)
  t.eq(s.blocks[1].last, 4)
  t.eq(rows(s.fenced), { 5, 6 })
end)

t.test("a fence closes only with a fence as long, of the same character", function()
  local s = scan({ "````", "```", "~~~~", "````", "out" })
  t.eq(rows(s.fenced), { 0, 1, 2, 3 })
end)

t.test("rows: a callout's lines are markdown, its >> and << lines aren't", function()
  local s = scan({ ">> note", "a", "b", "<<" })
  t.eq(rows(s.block), { 0, 1, 2, 3 })
  t.eq(rows(s.verbatim), { 0, 3 })
  t.eq(rows(s.note), { 1, 2 })
  t.eq(s.note[1], blocks.kinds.note)
end)

t.test("rows: code, latex, mermaid and boxed blocks aren't markdown", function()
  for _, tag in ipairs({ "python", "latex", "mermaid", "boxed" }) do
    local s = scan({ ">> " .. tag, "a", "<<" })
    t.eq(rows(s.verbatim), { 0, 1, 2 }, tag)
    t.eq(rows(s.note), {}, tag)
  end
end)

t.test("the scan is kept until the buffer changes", function()
  local buf = t.scratch({ ">> note", "x", "<<" })
  local first = blocks.scan(buf)
  t.ok(blocks.scan(buf) == first, "same scan")
  vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "y" })
  t.ok(blocks.scan(buf) ~= first, "a new scan")
end)
