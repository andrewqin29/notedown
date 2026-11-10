-- notedown: a note format for Neovim, built on markdown and rendered in the
-- buffer. Its parts:
--
--   render          drawing each markdown file, and showing the line under
--                   the cursor as typed
--   markdown        headings, lists, checkboxes, quotes, ---, ==highlights==
--   blocks          >> note / tip / important / warning / caution, >> python
--                   and other code, >> latex, >> mermaid, >> boxed
--   justify         justified paragraphs, lines broken for the whole paragraph
--   typography      dashes, curly quotes, fractions, © ® ™
--   footnotes       [^label] numbered, and the section of them kept up to date
--   images          typeset math, diagrams and pictures, with snacks.nvim
--   heading_images  # and ## drawn larger, as images
--   queries         markdown syntax the format replaces does nothing;
--                   *bold* and _italic_
--   highlights      colors
--   breadcrumb      the heading path at the top of markdown windows
--   toc             gO or :toc, a table of contents popup
--   help            :help or F1, what to write and the commands
--   reading         :read, reading mode, and :raw, raw reading mode

local M = {}

local done = false

-- What each markdown file gets besides rendering.
local function markdown_file(buf)
  -- How far in wrapped lines continue (blocks.lua, list_pattern).
  vim.bo[buf].formatlistpat = require("notedown.blocks").list_pattern
  -- The table of contents popup, in place of nvim's own gO (location list).
  vim.keymap.set("n", "gO", function() require("notedown.toc").open() end, { buffer = buf, desc = "Table of contents" })
  require("notedown.footnotes").attach(buf)
  vim.keymap.set("n", "<F1>", function() require("notedown.help").open() end, { buffer = buf, desc = "notedown help" })
end

-- Lowercase commands for markdown: nvim only allows commands of your own that
-- start with a capital, so :read, :raw, :toc, :help and :h typed on their own
-- are turned into :Read, :Raw, :Toc and :Help when you press Enter. With anything after
-- them they're nvim's own: :read file puts its text below the cursor, :help
-- topic opens nvim's help.
local LOWERCASE = { read = "Read", raw = "Raw", toc = "Toc", help = "Help", h = "Help" }

local function lowercase()
  local command = vim.fn.getcmdtype() == ":" and LOWERCASE[vim.fn.getcmdline()]
  if command and (vim.bo.filetype == "markdown" or require("notedown.reading").active()) then
    return "<C-u>" .. command .. "<CR>"
  end
  return "<CR>"
end

local function attach(buf)
  if require("notedown.render").attach(buf) then markdown_file(buf) end
end

-- Called once, at startup (plugin/notedown.lua): before any markdown file
-- opens, since it changes how nvim-treesitter highlights markdown.
function M.setup()
  if done then return end
  done = true

  require("notedown.highlights").setup()
  require("notedown.queries").setup()
  require("notedown.images").setup()
  require("notedown.render").setup()
  require("notedown.breadcrumb").setup()
  require("notedown.reading").setup()

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("notedown", { clear = true }),
    pattern = "markdown",
    callback = function(ev) attach(ev.buf) end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then attach(buf) end
  end

  vim.api.nvim_create_user_command("Toc", function() require("notedown.toc").open() end,
    { desc = "Table of contents of the markdown note" })
  vim.api.nvim_create_user_command("Notedown", function() require("notedown.render").toggle() end,
    { desc = "Toggle rendering markdown notes" })
  vim.api.nvim_create_user_command("Help", function() require("notedown.help").open() end,
    { desc = "notedown's help" })
  vim.keymap.set("c", "<CR>", lowercase, { expr = true, desc = "Bare :read, :toc and :help in markdown" })
end

return M
