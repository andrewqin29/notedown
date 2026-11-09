-- Reading mode for markdown (:Read, or :read with nothing after it): the note
-- in a window WIDTH of the screen wide (0: all of it) on a plain black
-- backdrop, without line numbers, everything rendered even under the cursor,
-- read-only, and a minimal status line (the note's name and how far through it
-- you are). Moving around works as usual; Esc or :Read again goes back.
--
-- Raw reading mode (:Raw, or :raw) is the same, with nothing rendered: the
-- note's text as typed, images hidden. :Read and :Raw switch between the two.
--
-- The column is snacks.nvim's zen window. Closing it any way (:q, or moving to
-- another window) leaves reading mode too.

local M = {}

-- snacks reads a width up to 1 as a share of the screen, and 0 as all of it.
M.WIDTH, M.MIN = 0, 60

-- Keys that would change the text, made to do nothing while reading.
local EDIT_KEYS = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C", "x", "X", "d", "D",
  "p", "P", "r", "R", "J", "u", "U", ".", "<C-r>", "<C-a>", "<C-x>", "<", ">", "=" }

local state -- { buf, zen, modifiable, statusline, raw } while reading

local function exit()
  if not state then return end
  local s = state
  state = nil
  if vim.api.nvim_buf_is_valid(s.buf) then
    vim.bo[s.buf].modifiable = s.modifiable
    for _, key in ipairs(EDIT_KEYS) do pcall(vim.keymap.del, { "n", "x" }, key, { buffer = s.buf }) end
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = s.buf })
    local render = require("notedown.render")
    render.everywhere(s.buf, false)
    render.raw(s.buf, false)
  end
  vim.o.statusline = s.statusline
  pcall(function() require("lualine").hide({ unhide = true }) end)
  if s.zen:valid() then s.zen:close() end
end

-- Rendered, or raw, and the status line saying which.
local function look(raw)
  state.raw = raw
  local render = require("notedown.render")
  render.everywhere(state.buf, not raw)
  render.raw(state.buf, raw)
  vim.o.statusline = "%#Comment#  %t" .. (raw and "  ·  raw" or "") .. "%=%p%%  "
end

local function enter(raw)
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
  vim.w[zen.win].notedown_reading = true
  require("notedown.breadcrumb").update(zen.win)

  vim.bo[buf].modifiable = false
  for _, key in ipairs(EDIT_KEYS) do
    vim.keymap.set({ "n", "x" }, key, "<Nop>", { buffer = buf, desc = "Reading mode: read-only" })
  end
  -- Esc leaves reading mode (clearing search highlights too, as Esc
  -- commonly does).
  vim.keymap.set("n", "<Esc>", function()
    vim.cmd("nohlsearch")
    exit()
  end, { buffer = buf, desc = "Leave reading mode" })
  pcall(function() require("lualine").hide({ place = { "statusline" }, unhide = false }) end)
  look(raw)
end

-- Reading mode, or with raw raw reading mode: on, off, or switched to the
-- other.
function M.toggle(raw)
  raw = raw or false
  if not state then
    enter(raw)
  elseif state.raw == raw then
    exit()
  else
    look(raw)
  end
end

function M.active() return state ~= nil end

function M.setup()
  vim.api.nvim_create_user_command("Read", function() M.toggle(false) end, { desc = "Toggle reading mode for markdown" })
  vim.api.nvim_create_user_command("Raw", function() M.toggle(true) end,
    { desc = "Toggle raw reading mode for markdown: nothing rendered" })
end

return M
