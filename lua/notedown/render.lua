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
-- In insert mode the block being edited shows as typed, and the rest of the
-- note stays rendered: the editing zone. It's the >> block or fence the cursor
-- is in, or else the lines around it up to blank lines (a paragraph, a list),
-- worked out when insert mode starts. It only grows while you type (lines added
-- at its edges are in it), so nothing around you changes from rendered to typed
-- mid-sentence; moving the cursor out of it starts a new one where it lands.
-- Its colors (a callout's tint, ==highlights==) stay.
--
-- Notes show rendered in normal, command-line, terminal, insert and replace
-- mode, and as typed in visual mode, in diff windows and when scrolled
-- sideways.

local M = {}

local ns = vim.api.nvim_create_namespace("notedown")

-- Modes that show a note rendered, by the first letter of mode(true): normal
-- (and operator-pending), command-line, terminal, insert and replace.
local MODES = { n = true, c = true, t = true, i = true, R = true }
-- Modes that type, and so have an editing zone.
local TYPING = { i = true, R = true }

-- After a change: render at once, then at most once per this many ms while
-- changes keep coming, and while typing in insert mode at most once per
-- DEBOUNCE_TYPING (marks move with the text in between).
local DEBOUNCE, DEBOUNCE_TYPING = 100, 300

-- The editing zone's extent, as an extmark from its first line to the end of
-- its last, which widens as text is put in at either end.
local zone_ns = vim.api.nvim_create_namespace("notedown.zone")

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
-- everywhere, raw, zone }. rows has the typed marks on each row; hidden, the ones
-- given way for the cursor; shown, whether the rest are placed. tick and width
-- are what the marks were worked out for. everywhere is reading mode's (no line
-- shows as typed), raw raw reading mode's (nothing rendered). zone is the editing zone's extmark, in insert mode.
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

-- The rows of the block the row is in: its >> block or fence, else the lines
-- around it up to blank lines, headings and blocks; a blank line or a heading
-- on its own.
local function block_rows(buf, row)
  local scan = require("notedown.blocks").scan(buf)
  for _, block in ipairs(scan.blocks) do
    if row >= block.first and row <= block.last then return block.first, block.last end
  end
  local lines = scan.lines
  local function joins(r)
    local line = lines[r + 1]
    return line and line:find("%S") and not line:find("^#+%s") and not scan.block[r]
      and (scan.fenced[r] or false) == (scan.fenced[row] or false)
  end
  if not joins(row) then return row, row end
  local first, last = row, row
  while first > 0 and joins(first - 1) do first = first - 1 end
  while joins(last + 1) do last = last + 1 end
  return first, last
end

-- The rows that show as typed in insert mode, made or kept for the cursor's
-- row (see the top of this file).
local function zone(buf, state, row)
  if state.zone then
    local mark = vim.api.nvim_buf_get_extmark_by_id(buf, zone_ns, state.zone, { details = true })
    if mark[1] and row >= mark[1] and row <= mark[3].end_row then return mark[1], mark[3].end_row end
  end
  local first, last = block_rows(buf, row)
  vim.api.nvim_buf_clear_namespace(buf, zone_ns, 0, -1)
  local line = vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1] or ""
  state.zone = vim.api.nvim_buf_set_extmark(buf, zone_ns, first, 0, {
    end_row = last,
    end_col = #line,
    right_gravity = false,
    end_right_gravity = true,
  })
  return first, last
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

  local mode = vim.fn.mode(true):sub(1, 1)
  local rendered = M.enabled
    and not state.raw
    and MODES[mode]
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

  local typing = rendered and TYPING[mode] and not state.everywhere
  if not typing and state.zone then
    vim.api.nvim_buf_clear_namespace(buf, zone_ns, 0, -1)
    state.zone = nil
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

  -- The typed marks on the cursor's line, or in insert mode its editing zone,
  -- in the buffer you're in, give way.
  local hidden, set = {}, {}
  if not state.everywhere and buf == vim.api.nvim_get_current_buf() then
    local row = vim.api.nvim_win_get_cursor(win)[1] - 1
    local first, last = row, row
    if typing then first, last = zone(buf, state, row) end
    for r = first, last do
      for _, mark in ipairs(state.rows[r] or {}) do
        if not set[mark] then
          set[mark] = true
          hidden[#hidden + 1] = mark
        end
      end
    end
  end
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
    local typing = TYPING[vim.fn.mode(true):sub(1, 1)]
    state.timer:start(typing and DEBOUNCE_TYPING or DEBOUNCE, 0, function()
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
    { "BufWinEnter", "BufLeave", "CursorMoved", "CursorMovedI", "ModeChanged", "TextChanged", "TextChangedI",
      "DiffUpdated" },
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

-- Raw reading mode: nothing rendered, images included.
function M.raw(buf, on)
  local state = buffers[buf]
  if not state then return end
  state.raw = on
  M.request(buf)
  require("notedown.images").update(buf)
end

-- Whether the buffer's images show (images.lua): not when rendering is off
-- or in raw reading mode.
function M.shows(buf)
  return M.enabled and not (buffers[buf] and buffers[buf].raw)
end

function M.toggle()
  M.enabled = not M.enabled
  for buf in pairs(buffers) do
    M.request(buf)
    require("notedown.images").update(buf)
  end
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
