-- Footnotes (footnotes.lua): numbering, keeping the section, drawing.
local t = require("tests.t")
local footnotes = require("notedown.footnotes")
local blocks = require("notedown.blocks")

local function read(lines) return footnotes.read(blocks.scan(t.scratch(lines))) end

local function synced(lines)
  local buf = t.scratch(lines)
  footnotes.sync(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

t.test("numbered by first reference, any label, each once", function()
  local notes = read({ "a[^z] b[^ajk129] c[^z]", "d[^1]" })
  t.eq(notes.order, { "z", "ajk129", "1" })
  t.eq(#notes.refs, 4)
  t.eq(notes.number.ajk129, 2)
end)

t.test("not references: in code, or a definition's own text", function()
  local notes = read({ "`[^a]` and", ">> python", "x[^b]", "<<", "[^c]: see [^d]" })
  t.eq(notes.order, {})
  t.eq(#notes.defs, 1)
end)

t.test("sync: a stub for each new label, in order of use, after a blank line", function()
  t.eq(synced({ "One[^b] two[^a] three[^b]." }), { "One[^b] two[^a] three[^b].", "", "[^b]: ", "[^a]: " })
end)

t.test("sync: definitions keep their text, put in order of use", function()
  t.eq(synced({ "x[^a] y[^b]", "", "[^b]: Bee.", "[^a]: Ay." }), { "x[^a] y[^b]", "", "[^a]: Ay.", "[^b]: Bee." })
end)

t.test("sync: a label no longer used goes, text and all", function()
  t.eq(synced({ "x[^a]", "", "[^a]: Ay.", "[^old]: Gone." }), { "x[^a]", "", "[^a]: Ay." })
  t.eq(synced({ "no footnotes", "", "[^old]: Gone." }), { "no footnotes", "" })
end)

t.test("sync: the blank lines above the section are kept", function()
  t.eq(synced({ "x[^a] y[^b]", "", "", "", "[^a]: Ay." }), { "x[^a] y[^b]", "", "", "", "[^a]: Ay.", "[^b]: " })
  t.eq(synced({ "x[^a]", "", "", "" }), { "x[^a]", "", "", "", "[^a]: " })
end)

t.test("sync: a definition elsewhere moves into the section", function()
  t.eq(synced({ "x[^a]", "[^a]: Ay.", "more text" }), { "x[^a]", "more text", "", "[^a]: Ay." })
end)

t.test("sync: a note without footnotes, or already right, is left alone", function()
  for _, lines in ipairs({ { "text", "", "" }, { "x[^a]", "", "[^a]: Ay." } }) do
    local buf = t.scratch(lines)
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    footnotes.sync(buf)
    t.eq(vim.api.nvim_buf_get_changedtick(buf), tick, lines[1])
  end
end)

t.test("typing a reference adds its stub; one u undoes both", function()
  local buf = t.open({ "Text" })
  t.cursor(1)
  t.keys("A[^note]<Esc>")
  t.settle()
  t.eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "Text[^note]", "", "[^note]: " })
  t.keys("u")
  t.settle()
  t.eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "Text", "" })
end)

t.test("drawn: references as superscript numbers, the section numbered and ruled", function()
  local buf = t.open({ "Bits[^bits] and more[^ctx].", "", "[^bits]: Smallest unit.", "[^ctx]: Context." })
  t.cursor(2)
  t.eq(vim.list_slice(t.body(), 1, 4), { "Bits¹ and more².", ("─"):rep(20), "1. Smallest unit.", "2. Context." })
  local marks = table.concat(t.marks(buf), "\n")
  t.ok(marks:find("hl NotedownFootnote", 1, true), marks)
end)
