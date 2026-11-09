-- Drawing notes. Each markdown file gets marks (extmarks) from every part of
-- the format: markdown.lua, blocks.lua, justify.lua and typography.lua. They
-- are worked out again after a change, or when the window's width changes,
-- and kept while the cursor moves.
--
-- A mark is { row, col, typed, opts }: opts is what nvim_buf_set_extmark
-- takes, and typed marks give way while the cursor is on their lines, so the
-- line under the cursor shows as typed. Marks that only color (a note block's
-- tint, a ==highlight==) aren't typed and stay.
--
-- Notes show rendered in normal, command-line and terminal mode, and as typed
-- in the others (insert, visual), in diff windows and when scrolled sideways.

local M = {}

local ns = vim.api.nvim_create_namespace("notedown")

-- Modes that show a note rendered (:h mode()).
local MODES = { n = true, c = true, t = true }

-- After a change: render at once, then at most once per this many ms while
-- changes keep coming.
local DEBOUNCE = 100

-- Window options while a note shows rendered. Otherwise each goes back to
-- its global value from when notedown started.
local WINDOW = {
  -- concealed text completely hidden, on the cursor line too (where its marks
  -- give way instead)
  conceallevel = 3,
  concealcursor = "",
  -- wrap between words, not inside them
  linebreak = true,
  -- a wrapped list item or quote continues under its text, as far in as
  -- 'formatlistpat' matches (blocks.lua, list_pattern)
  breakindent = true,
  breakindentopt = "list:-1",
}
local defaults = {}

-- Whether notes render at all (:Notedown toggles it).
M.enabled = true

-- By buffer: { marks, rows, hidden, shown, tick, width, timer, pending,
-- everywhere }. rows has the typed marks on each row; hidden, the ones given
-- way for the cursor; shown, whether the rest are placed. tick and width are
-- what the marks were worked out for. everywhere is reading mode's (no line
-- shows as typed).
local buffers = {}

local function show(buf, mark)
  if mark.id then return end
  mark.opts.strict = false
  local ok, id = pcall(vim.api.nvim_buf_set_extmark, buf, ns, mark.row, mark.col, mark.opts)
  if ok then
    mark.id = id
  else
    vim.notify_once("notedown: could not draw a mark (" .. id .. ")", vim.log.levels.ERROR)
  end
end

local function hide(buf, mark)
  if not mark.id then return end
  vim.api.nvim_buf_del_extmark(buf, ns, mark.id)
  mark.id = nil
end

-- Every part's marks for the buffer, and the typed ones by row.
local function marks(buf)
  local list, rows = {}, {}
  local function add(row, col, typed, opts)
    local mark = { row = row, col = col, typed = typed, opts = opts }
    list[#list + 1] = mark
    if typed then
      for r = row, opts.end_row or row do
        rows[r] = rows[r] or {}
        table.insert(rows[r], mark)
      end
    end
  end
  local scan = require("notedown.blocks").scan(buf)
  require("notedown.markdown").marks(buf, scan, add)
  require("notedown.blocks").marks(buf, scan, add)
  require("notedown.justify").marks(buf, scan, add)
  require("notedown.typography").marks(scan, add)
  return list, rows
end

local function set_option(win, name, value)
  if vim.api.nvim_get_option_value(name, { scope = "local", win = win }) ~= value then
    vim.api.nvim_set_option_value(name, value, { scope = "local", win = win })
  end
end

local function draw(buf)
  local state = buffers[buf]
  if not state or not vim.api.nvim_buf_is_valid(buf) then return end
  local win = require("notedown.window")(buf)
  if not win then return end

  local rendered = M.enabled
    and MODES[vim.fn.mode(true)]
    and vim.api.nvim_win_call(win, vim.fn.winsaveview).leftcol == 0
    and not vim.wo[win].diff
  for _, w in ipairs(vim.fn.win_findbuf(buf)) do
    for name, value in pairs(WINDOW) do
      if not rendered then
        value = defaults[name]
      elseif name == "concealcursor" and state.everywhere then
        -- concealed text stays concealed under the cursor too, which also
        -- keeps snacks from showing an image's source there
        value = "nc"
      end
      set_option(w, name, value)
    end
  end

  if not rendered then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for _, mark in ipairs(state.marks) do mark.id = nil end
    state.shown = false
    return
  end

  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local info = vim.fn.getwininfo(win)[1]
  local width = info.width - info.textoff
  if tick ~= state.tick or width ~= state.width then
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    state.marks, state.rows = marks(buf)
    state.tick, state.width, state.shown = tick, width, false
  end

  -- The typed marks on the cursor's line, in the buffer you're in, give way.
  local row
  if not state.everywhere and buf == vim.api.nvim_get_current_buf() then
    row = vim.api.nvim_win_get_cursor(win)[1] - 1
  end
  local hidden = row and state.rows[row] or {}
  local set = {}
  for _, mark in ipairs(hidden) do set[mark] = true end
  if not state.shown then
    for _, mark in ipairs(state.marks) do
      if not set[mark] then show(buf, mark) end
    end
    state.shown = true
  else
    for _, mark in ipairs(state.hidden or {}) do
      if not set[mark] then show(buf, mark) end
    end
  end
  for _, mark in ipairs(hidden) do hide(buf, mark) end
  state.hidden = hidden
end

-- Draw the buffer soon: at once for the cursor moving or the mode changing,
-- debounced for changes to the text.
function M.request(buf)
  local state = buffers[buf]
  if not state then return end
  local changed = vim.api.nvim_buf_get_changedtick(buf) ~= state.tick
  if changed then
    if state.timer:is_active() then
      state.pending = true
      return
    end
    state.timer:start(DEBOUNCE, 0, function()
      if state.pending then
        state.pending = false
        vim.schedule(function() draw(buf) end)
      end
    end)
  end
  vim.schedule(function() draw(buf) end)
end

local group = vim.api.nvim_create_augroup("notedown.render", { clear = true })

-- Start rendering the buffer, if it's a markdown file: not another buffer
-- holding markdown, such as an LSP hover popup. Whether it renders.
function M.attach(buf)
  if buffers[buf] then
    M.request(buf)
    return true
  end
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "markdown" or vim.bo[buf].buftype ~= "" then
    return false
  end
  buffers[buf] = { marks = {}, rows = {}, timer = assert(vim.uv.new_timer()) }
  vim.api.nvim_create_autocmd(
    { "BufWinEnter", "BufLeave", "CursorMoved", "ModeChanged", "TextChanged", "DiffUpdated" },
    { group = group, buffer = buf, callback = function() M.request(buf) end }
  )
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    callback = function()
      local state = buffers[buf]
      buffers[buf] = nil
      if state then state.timer:close() end
    end,
  })
  M.request(buf)
  return true
end

-- Reading mode: render the buffer everywhere, the cursor's line included.
function M.everywhere(buf, on)
  local state = buffers[buf]
  if not state then return end
  state.everywhere = on
  M.request(buf)
end

function M.toggle()
  M.enabled = not M.enabled
  for buf in pairs(buffers) do M.request(buf) end
end

function M.setup()
  for name in pairs(WINDOW) do defaults[name] = vim.o[name] end
  -- A window changing size changes where lines wrap (justify.lua) and how
  -- wide some marks are.
  vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    callback = function()
      for _, win in ipairs(vim.v.event.windows or {}) do
        if vim.api.nvim_win_is_valid(win) then M.request(vim.api.nvim_win_get_buf(win)) end
      end
    end,
  })
end

return M
