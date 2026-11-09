-- The note's headings (headings.lua), the breadcrumb and the table of
-- contents.
local t = require("tests.t")
local headings = require("notedown.headings")

local NOTE = {
  "# Chapter *One*",       -- 1
  "intro",                 -- 2
  "## Bits -- `bytes` ##", -- 3
  "text",                  -- 4
  "```",                   -- 5
  "# not a heading",       -- 6
  "```",                   -- 7
  ">> python",             -- 8
  "# a comment",           -- 9
  "<<",                    -- 10
  "#hashtag",              -- 11
  "### [Linked](url)",     -- 12
  "end",                   -- 13
}

t.test("headings: levels, rows and plain text; not in fences or blocks", function()
  local buf = t.scratch(NOTE)
  t.eq(headings.list(buf), {
    { row = 0, level = 1, text = "Chapter One" },
    { row = 2, level = 2, text = "Bits — bytes" },
    { row = 11, level = 3, text = "Linked" },
  })
end)

t.test("headings: the section a row is in", function()
  local list = headings.list(t.scratch({ "intro", "# A", "x", "## B", "y" }))
  t.eq(headings.current(list, 0), nil)
  t.eq(headings.current(list, 1), 1)
  t.eq(headings.current(list, 2), 1)
  t.eq(headings.current(list, 4), 2)
end)

t.test("headings: worked out again after a change", function()
  local buf = t.scratch({ "# A" })
  t.eq(#headings.list(buf), 1)
  vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "# B" })
  t.eq(#headings.list(buf), 2)
end)

local function winbar()
  return vim.api.nvim_eval_statusline(vim.wo.winbar, { winid = 0, use_winbar = true }).str
end

t.test("breadcrumb: the note's name, the headings above the cursor, where you are", function()
  t.open({ "# One", "x", "## Two", "y", "# Three", "z" }, "chapter")
  t.cursor(4)
  local bar = winbar()
  t.ok(vim.startswith(bar, " 󰈙 chapter  ›  One  ›  Two"), bar)
  t.ok(vim.endswith(bar, "2/3 · 57% "), bar)
  t.cursor(6)
  t.ok(winbar():find("󰈙 chapter  ›  Three", 1, true), winbar())
end)

t.test("breadcrumb: long titles are cut short to fit", function()
  t.open({ "# " .. ("Very long chapter title "):rep(3), "## " .. ("Long section "):rep(4), "x" })
  vim.cmd("vsplit")
  vim.cmd("vertical resize 50")
  t.cursor(3)
  local bar = winbar()
  t.ok(bar:find("…", 1, true), bar)
  t.ok(vim.fn.strdisplaywidth(bar) <= 50, bar)
end)

t.test("breadcrumb: only in markdown windows", function()
  t.open({ "# A" })
  t.ok(vim.wo.winbar ~= "", "markdown")
  vim.cmd("enew")
  t.eq(vim.wo.winbar, "")
end)

local function toc_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "notedown_toc" then return win end
  end
end

t.test("table of contents: the headings, indented, on the current one", function()
  t.open({ "# One", "x", "## Two", "y", "# Three" })
  t.cursor(4)
  t.keys("gO")
  local win = toc_window()
  t.ok(win, "opens")
  t.eq(vim.api.nvim_get_current_win(), win)
  t.eq(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "  One ", "▶   Two ", "  Three " })
  t.eq(vim.api.nvim_win_get_cursor(win)[1], 2)
end)

t.test("table of contents: Enter jumps to the heading and closes it", function()
  local buf = t.open({ "# One", "x", "## Two", "y", "# Three" })
  vim.cmd("Toc")
  t.keys("j<CR>")
  t.eq(toc_window(), nil)
  t.eq(vim.api.nvim_get_current_buf(), buf)
  t.eq(vim.api.nvim_win_get_cursor(0)[1], 5)
end)

t.test("table of contents: q closes it", function()
  t.open({ "# One" })
  vim.cmd("Toc")
  t.keys("q")
  t.eq(toc_window(), nil)
end)

t.test("table of contents: not for a note without headings", function()
  t.open({ "no headings" })
  local notify, said = vim.notify, nil
  vim.notify = function(msg) said = msg end
  vim.cmd("Toc")
  vim.notify = notify
  t.eq(said, "Table of contents: no headings")
  t.eq(toc_window(), nil)
end)

t.test(":toc and :read typed in markdown are :Toc and :Read", function()
  t.open({ "# One" })
  t.keys(":toc<CR>")
  t.ok(toc_window(), ":toc opens it")
end)

local function help_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "notedown_help" then return win end
  end
end

t.test("help: :help, :h and F1 open it in markdown, centered; q and Esc close it", function()
  t.open({ "# One" })
  for _, open in ipairs({ ":help<CR>", ":h<CR>", "<F1>" }) do
    t.keys(open)
    local win = help_window()
    t.ok(win, open)
    local config = vim.api.nvim_win_get_config(win)
    t.ok(math.abs(2 * config.col + config.width + 2 - vim.o.columns) <= 1, "centered")
    t.keys(open == "<F1>" and "<Esc>" or "q")
    t.eq(help_window(), nil, open)
  end
end)

t.test("help: :help with a topic, or outside markdown, is nvim's", function()
  t.open({ "# One" })
  t.keys(":help options<CR>")
  t.eq(help_window(), nil)
  t.eq(vim.bo.buftype, "help")
  vim.cmd("only")
  vim.cmd("enew")
  t.keys(":help<CR>")
  t.eq(help_window(), nil)
  t.eq(vim.bo.buftype, "help")
end)
