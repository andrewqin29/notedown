-- Markdown's highlight queries, changed for the format (queries.lua).
local t = require("tests.t")

local function captures(row, col)
  local names = {}
  for _, c in ipairs(vim.treesitter.get_captures_at_pos(0, row, col)) do
    names[#names + 1] = c.capture .. "." .. c.lang
  end
  return names
end

local function has(row, col, name)
  return vim.tbl_contains(captures(row, col), name)
end

t.test("*bold* and _italic_; **x** and __x__ are plain", function()
  t.open({ "*b* _i_ **n** __n__" })
  t.ok(has(0, 1, "markup.strong.markdown_inline"), "*b* bold")
  t.ok(not has(0, 1, "markup.italic.markdown_inline"), "*b* not italic")
  t.ok(has(0, 5, "markup.italic.markdown_inline"), "_i_ italic")
  t.ok(not has(0, 10, "markup.strong.markdown_inline"), "**n** plain")
  t.ok(not has(0, 16, "markup.strong.markdown_inline"), "__n__ plain")
end)

t.test("setext headings are paragraphs", function()
  t.open({ "Title", "=====" })
  t.ok(not has(0, 1, "markup.heading.1.markdown"), vim.inspect(captures(0, 1)))
end)

t.test("``` fences show as typed, not as code", function()
  t.open({ "```python", "x = 1", "```" })
  t.eq(vim.tbl_filter(function(c) return c:find("python") or c:find("raw.block") end, captures(1, 0)), {})
  -- the fence lines aren't hidden
  t.eq(vim.list_slice(t.body(), 1, 3), { "```python", "x = 1", "```" })
end)
