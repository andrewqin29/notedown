-- Justified paragraphs (justify.lua), checked on the screen.
local t = require("tests.t")

local PARAGRAPH = "The program starts off as a high-level C program that can be read and understood "
  .. "by humans, but this paragraph is long enough to wrap across several lines, so how its "
  .. "lines are broken and stretched can be checked properly against the width of the window."

local function words(lines)
  return vim.split(vim.trim(table.concat(lines, " ")), "%s+")
end

-- The paragraph's screen lines, from the window's first line.
local function paragraph_lines()
  local lines = {}
  for _, line in ipairs(t.body()) do
    if line == "" then break end
    lines[#lines + 1] = line
  end
  return lines
end

t.test("every line but the last reaches one column short of the window", function()
  t.open({ PARAGRAPH })
  local lines = paragraph_lines()
  t.ok(#lines >= 3, "wraps")
  for i = 1, #lines - 1 do
    t.eq(vim.fn.strdisplaywidth(lines[i]), 79, "line " .. i)
  end
  t.eq(words(lines), words({ PARAGRAPH }), "the same words")
end)

t.test("the last line isn't one word alone", function()
  for _, extra in ipairs({ "", " end", " the very end", " and then the very end of it" }) do
    t.open({ PARAGRAPH .. extra })
    local lines = paragraph_lines()
    t.ok(#words({ lines[#lines] }) > 1, "last line of: ..." .. extra)
  end
end)

t.test("a narrower window: lines reach its width instead", function()
  t.open({ PARAGRAPH })
  vim.cmd("vsplit")
  vim.cmd("vertical resize 50")
  t.settle()
  local row = 0
  for _, line in ipairs(t.body()) do
    row = row + 1
    if row > 3 then break end
    -- the left window's half of the screen line
    t.eq(vim.fn.strdisplaywidth(vim.fn.strcharpart(line, 0, 50):gsub("%s+$", "")), 49, "line " .. row)
  end
end)

t.test("in a note block, after its bar", function()
  t.open({ ">> note", PARAGRAPH, "<<" })
  local lines = t.body()
  t.eq(lines[1], "▋ 󰋽 Note")
  for i = 2, 4 do
    t.eq(vim.fn.strcharpart(lines[i], 0, 2), "▋ ", "bar on line " .. i)
    t.eq(vim.fn.strdisplaywidth(lines[i]), 79, "line " .. i)
  end
end)

t.test("only plain paragraphs", function()
  local long = (" word"):rep(30)
  local buf = t.open({
    "- a list item" .. long, "# a heading" .. long, "> a quote" .. long,
    "    indented" .. long, "with *emphasis*" .. long, "with `code`" .. long, "short line",
  })
  local count = 0
  require("notedown.justify").marks(buf, require("notedown.blocks").scan(buf), function() count = count + 1 end)
  t.eq(count, 0)
end)

t.test("not in a window narrower than 20 columns", function()
  local buf = t.open({ PARAGRAPH })
  vim.cmd("vsplit")
  vim.cmd("vertical resize 15")
  local count = 0
  require("notedown.justify").marks(buf, require("notedown.blocks").scan(buf), function() count = count + 1 end)
  t.eq(count, 0)
end)
