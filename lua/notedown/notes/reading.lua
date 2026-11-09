-- Reading mode for markdown (:Read, or :read with nothing after it): the note
-- in a window WIDTH of the screen wide (0: all of it) on a plain black
-- backdrop, without line numbers, everything rendered even under the cursor,
-- read-only, and a minimal status line (the note's name and how far through it
-- you are). Moving around works as usual; Esc or :Read again goes back.
--
-- The column is snacks.nvim's zen window. Closing it any way (:q, or moving to
-- another window) leaves reading mode too.

local M = {}

-- snacks reads a width up to 1 as a share of the screen, and 0 as all of it.
M.WIDTH, M.MIN = 0, 60

-- Keys that would change the text, made to do nothing while reading.
local EDIT_KEYS = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C", "x", "X", "d", "D",
  "p", "P", "r", "R", "J", "u", "U", ".", "<C-r>", "<C-a>", "<C-x>", "<", ">", "=" }

local state -- { buf, zen, modifiable, statusline } while reading

-- Render-markdown's settings for this buffer: keep everything rendered under
-- the cursor (no anti-conceal), and let concealed text stay concealed on the
-- cursor line, which also keeps snacks from showing an image's source there.
local function rendered_everywhere(buf, on)
  local config = require("notedown.state").get(buf)
  config.anti_conceal.enabled = not on
  config.win_options.concealcursor.rendered = on and "nc" or ""
  require("notedown.api").render({ buf = buf })
end

local function exit()
  if not state then return end
  local s = state
  state = nil
  if vim.api.nvim_buf_is_valid(s.buf) then
    vim.bo[s.buf].modifiable = s.modifiable
    for _, key in ipairs(EDIT_KEYS) do pcall(vim.keymap.del, { "n", "x" }, key, { buffer = s.buf }) end
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = s.buf })
    rendered_everywhere(s.buf, false)
  end
  vim.o.statusline = s.statusline
  pcall(function() require("lualine").hide({ unhide = true }) end)
  if s.zen:valid() then s.zen:close() end
end

local function enter()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "markdown" then
    vim.notify("Reading mode is for markdown files", vim.log.levels.WARN)
    return
  end

  state = { buf = buf, modifiable = vim.bo[buf].modifiable, statusline = vim.o.statusline }
  local zen = Snacks.zen({
    toggles = {},
    show = { statusline = true, tabline = false },
    win = {
      -- Given as a function: snacks shows a "zoom" label in the top right of a
      -- window whose width is literally 0 (full width), but not of one whose
      -- width comes from a function, even one giving 0.
      width = function() return M.WIDTH end,
      min_width = M.MIN,
      backdrop = { blend = 0, transparent = false },
      wo = { number = false, relativenumber = false, signcolumn = "no",
        foldcolumn = "0", statuscolumn = "", cursorline = false },
    },
    on_close = function() vim.schedule(exit) end,
  })
  if not zen then
    state = nil
    return
  end
  state.zen = zen

  -- The breadcrumb stays at the top (floating windows don't get it otherwise).
  vim.w[zen.win].notes_reading = true
  require("notedown.notes.breadcrumb").update(zen.win)

  vim.bo[buf].modifiable = false
  for _, key in ipairs(EDIT_KEYS) do
    vim.keymap.set({ "n", "x" }, key, "<Nop>", { buffer = buf, desc = "Reading mode: read-only" })
  end
  -- Esc leaves reading mode (in place of its usual clearing of search
  -- highlights and closing of popups, in init.lua).
  vim.keymap.set("n", "<Esc>", function()
    vim.cmd("nohlsearch")
    exit()
  end, { buffer = buf, desc = "Leave reading mode" })
  rendered_everywhere(buf, true)

  pcall(function() require("lualine").hide({ place = { "statusline" }, unhide = false }) end)
  vim.o.statusline = "%#Comment#  %t%=%p%%  "
end

function M.toggle()
  if state then exit() else enter() end
end

function M.active() return state ~= nil end

-- Lowercase commands for markdown: nvim only allows commands of your own that
-- start with a capital, so :read and :toc typed on their own are turned into
-- :Read and :Toc (notes/toc.lua) when you press Enter. With anything after
-- it, :read is nvim's own (put a file's text below the cursor).
local LOWERCASE = { read = "Read", toc = "Toc" }

function M.setup()
  vim.api.nvim_create_user_command("Read", M.toggle, { desc = "Toggle reading mode for markdown" })
  vim.keymap.set("c", "<CR>", function()
    local command = vim.fn.getcmdtype() == ":" and LOWERCASE[vim.fn.getcmdline()]
    if command and (vim.bo.filetype == "markdown" or state) then
      return "<C-u>" .. command .. "<CR>"
    end
    return "<CR>"
  end, { expr = true, desc = "Bare :read and :toc in markdown" })
end

return M
