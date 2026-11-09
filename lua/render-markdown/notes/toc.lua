-- The note's headings in a small popup at the top left of its window (gO or
-- :toc): j/k to move, Enter to jump to a heading, q or Esc to close. It
-- opens on the section the cursor is in.

local M = {}

local ns = vim.api.nvim_create_namespace("render-markdown.notes.toc")

function M.open()
  local src_win = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(src_win)
  if vim.bo[buf].filetype ~= "markdown" then
    vim.notify("Table of contents: not a markdown file", vim.log.levels.WARN)
    return
  end
  local headings = require("render-markdown.notes.headings")
  local list = headings.list(buf)
  if #list == 0 then
    vim.notify("Table of contents: no headings", vim.log.levels.INFO)
    return
  end
  local current = headings.current(list, vim.api.nvim_win_get_cursor(src_win)[1] - 1) or 1

  local lines, widest = {}, 0
  for i, heading in ipairs(list) do
    local mark = i == current and "▶ " or "  "
    lines[i] = mark .. ("  "):rep(heading.level - 1) .. heading.text .. " "
    widest = math.max(widest, vim.fn.strdisplaywidth(lines[i]))
  end

  local outline = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(outline, 0, -1, false, lines)
  vim.bo[outline].modifiable = false
  vim.bo[outline].bufhidden = "wipe"
  vim.bo[outline].filetype = "notes_outline"
  for i, heading in ipairs(list) do
    vim.api.nvim_buf_set_extmark(outline, ns, i - 1, 0, {
      end_col = #lines[i],
      hl_group = "RenderMarkdownH" .. heading.level,
    })
  end

  local win = vim.api.nvim_open_win(outline, true, {
    relative = "win",
    win = src_win,
    row = 0,
    col = 0,
    width = math.max(10, math.min(widest, vim.api.nvim_win_get_width(src_win) - 4)),
    height = math.max(1, math.min(#list, vim.api.nvim_win_get_height(src_win) - 3)),
    border = "rounded",
    title = " Contents ",
    style = "minimal",
  })
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  vim.api.nvim_win_set_cursor(win, { current, 0 })

  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  local function jump()
    local heading = list[vim.api.nvim_win_get_cursor(win)[1]]
    close()
    if vim.api.nvim_win_is_valid(src_win) then
      vim.api.nvim_set_current_win(src_win)
      vim.api.nvim_win_set_cursor(src_win, { heading.row + 1, 0 })
      vim.cmd("normal! zt")
    end
  end
  local opts = { buffer = outline, nowait = true }
  vim.keymap.set("n", "<CR>", jump, opts)
  vim.keymap.set("n", "q", close, opts)
  vim.keymap.set("n", "<Esc>", close, opts)
  vim.api.nvim_create_autocmd("WinLeave", { buffer = outline, once = true, callback = close })
end

return M
