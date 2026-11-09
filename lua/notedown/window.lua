-- The window that markdown rendering measures for a buffer (its width, for
-- justifying, sizing and centering): the current window when it shows the
-- buffer, so reading mode's centered window wins over the one behind it, else
-- the first window showing it. nil when no window shows it.
--
-- (Text is measured with vim.api.nvim_strwidth throughout, not strdisplaywidth,
-- which measures as if in the current window: with 'linebreak' and
-- 'breakindent' on, text wider than the window counts the indent of each
-- wrapped line too.)
return function(buf)
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) == buf then return win end
  local first = vim.fn.bufwinid(buf)
  return first ~= -1 and first or nil
end
