-- Typographic punctuation (typography.lua).
local t = require("tests.t")
local typography = require("notedown.typography")

-- The line as drawn: each mark's text over the bytes it covers.
local function typeset(line, skip)
  local marks = {}
  typography.marks({ lines = { line }, fenced = skip or {}, verbatim = {} }, function(_, col, typed, opts)
    t.ok(typed, "typed")
    marks[#marks + 1] = { col, opts.end_col, opts.virt_text[1][1] }
  end)
  table.sort(marks, function(a, b) return a[1] > b[1] end)
  for _, m in ipairs(marks) do
    t.eq(vim.fn.strdisplaywidth(m[3]), vim.fn.strdisplaywidth(line:sub(m[1] + 1, m[2])), "same width as typed")
    line = line:sub(1, m[1]) .. m[3] .. line:sub(m[2] + 1)
  end
  return line
end

t.test("quotes curl open and closed", function()
  t.eq(typeset([[He said "it's done" and 'that's that.']]), "He said “it’s done” and ‘that’s that.’")
  t.eq(typeset([[("in brackets") and -"after a dash"]]), "(“in brackets”) and -“after a dash”")
end)

t.test("apostrophes", function()
  t.eq(typeset("don't, the '90s, James' book"), "don’t, the ’90s, James’ book")
end)

t.test("-- is a dash, drawn in the room of the two characters", function()
  t.eq(typeset("cup--or this -- that"), "cup——or this —— that")
end)

t.test("not options, longer runs, arrows or html comments", function()
  for _, line in ipairs({ "run --help", "--verbose", "a --- b", "x --> y", "<!-- note -->" }) do
    t.eq(typeset(line), line)
  end
end)

t.test("fractions, not dates, paths or decimals", function()
  t.eq(typeset("add 1/2 cup or 15/16"), "add ¹⁄₂ cup or ¹⁵⁄₁₆")
  for _, line in ipairs({ "11/08/2026", "src/1/2", "1/2.5", "a1/2" }) do
    t.eq(typeset(line), line)
  end
end)

t.test("(c) before a year, (r) after a word, (tm)", function()
  t.eq(typeset("(c) 2026"), " ©  2026")
  t.eq(typeset("Acme(r) and Acme(tm)"), "Acme®   and Acme™   ")
  t.eq(typeset("options (a), (b), (c) or (r)"), "options (a), (b), (c) or (r)")
end)

t.test("not in code, math or html", function()
  for _, line in ipairs({ "`a--b \"q\"`", "$1/2$", '<a href="x--y">' }) do
    t.eq(typeset(line), line)
  end
end)

t.test("not on skipped rows, table delimiter rows or indented code", function()
  t.eq(typeset("a--b", { [0] = true }), "a--b")
  t.eq(typeset("|---|:--|"), "|---|:--|")
  t.eq(typeset('    print("x") -- y'), '    print("x") -- y')
end)

t.test("smarten: the same for text drawn elsewhere, with a one-column dash", function()
  t.eq(typography.smarten([[Bits -- "context" (c) 2026]]), "Bits — “context” © 2026")
end)
