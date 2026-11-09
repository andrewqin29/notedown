-- A breadcrumb at the top of markdown windows (the winbar): the note's name,
-- then the headings above where the cursor is, each in its heading color, and
-- on the right which section of how many and how far through the note:
--
--   󰈙 ch1  ›  1.1 Information is Bits  ›  Bits and bytes          2/4 · 38%
--
-- Long titles are cut short with … so it always fits.

local M = {}

local SEP = "  ›  "

local function escape(text) return (text:gsub("%%", "%%%%")) end

function M.render()
  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then return "" end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= "markdown" then return "" end

  local headings = require("notedown.notes.headings")
  local list = headings.list(buf)
  local row = vim.api.nvim_win_get_cursor(win)[1] - 1
  local index = headings.current(list, row)

  -- The heading of each level above the cursor.
  local path = {}
  for i = 1, index or 0 do
    local heading = list[i]
    for level = #path, 1, -1 do
      if path[level].level >= heading.level then table.remove(path, level) end
    end
    path[#path + 1] = heading
  end

  local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t:r")
  if name == "" then name = "[No Name]" end
  local left = " 󰈙 " .. name
  local lines = math.max(1, vim.api.nvim_buf_line_count(buf))
  local right = ("%s/%d · %d%% "):format(index or 0, #list, math.floor((row + 1) / lines * 100 + 0.5))

  -- Shorten the longest title until everything fits.
  local titles = vim.tbl_map(function(h) return h.text end, path)
  local room = vim.api.nvim_win_get_width(win) - vim.fn.strdisplaywidth(left .. right) - 2
  local function width()
    local total = 0
    for _, t in ipairs(titles) do total = total + vim.fn.strdisplaywidth(t) + #SEP end
    return total
  end
  while width() > room do
    local longest, at = 0, nil
    for i, t in ipairs(titles) do
      local w = vim.fn.strdisplaywidth(t)
      if w > longest then longest, at = w, i end
    end
    if not at or longest <= 4 then break end
    titles[at] = vim.fn.strcharpart(titles[at]:gsub("…$", ""), 0, longest - 2) .. "…"
  end

  local out = { "%#Comment#", escape(left) }
  for i, heading in ipairs(path) do
    out[#out + 1] = "%#Comment#" .. SEP
    out[#out + 1] = "%#NotedownH" .. heading.level .. "#" .. escape(titles[i])
  end
  out[#out + 1] = "%#Comment#%=" .. escape(right)
  return table.concat(out)
end

local EXPR = "%!v:lua.require'notedown.notes.breadcrumb'.render()"

-- Markdown windows get the breadcrumb, and a window showing something else
-- again loses it. Not floating windows (LSP hovers are markdown too), except
-- reading mode's.
function M.update(win)
  if not vim.api.nvim_win_is_valid(win) then return end
  local markdown = vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "markdown"
  local floating = vim.api.nvim_win_get_config(win).relative ~= ""
  local wanted = markdown and (not floating or vim.w[win].notes_reading)
  local current = vim.wo[win].winbar
  if wanted and current ~= EXPR then
    vim.wo[win].winbar = EXPR
  elseif not wanted and current == EXPR then
    vim.wo[win].winbar = ""
  end
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "WinNew" }, {
    group = vim.api.nvim_create_augroup("notedown.notes.breadcrumb", { clear = true }),
    callback = function() M.update(vim.api.nvim_get_current_win()) end,
  })
  for _, win in ipairs(vim.api.nvim_list_wins()) do M.update(win) end
end

return M
