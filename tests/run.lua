-- notedown's tests:
--
--   nvim --headless --clean -u tests/run.lua                 all of them
--   nvim --headless --clean -u tests/run.lua -- toc          those whose name has "toc"
--   nvim --headless --clean -u tests/run.lua -- --update     rewrite the snapshots
--
-- They need only Neovim, which comes with the markdown parsers and queries.

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
package.path = root .. "/?.lua;" .. package.path

vim.o.columns, vim.o.lines = 80, 40
vim.o.laststatus = 0
vim.o.ruler = false
vim.o.showmode = false
vim.o.swapfile = false
vim.cmd("filetype plugin indent on")
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(ev) vim.treesitter.start(ev.buf) end,
})
vim.cmd.runtime("plugin/notedown.lua")

local t = require("tests.t")
local filter
local args = vim.v.argv
local dashes = vim.fn.index(args, "--")
if dashes >= 0 then
  for i = dashes + 2, #args do
    if args[i] == "--update" then t.update = true else filter = args[i] end
  end
end

-- Scheduled rather than in VimEnter itself, where the files tests open
-- wouldn't get their autocommands (FileType...).
vim.schedule(function()
  t.run(vim.fn.glob(root .. "/tests/*_spec.lua", false, true), filter)
end)
