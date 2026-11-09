-- The headings of a markdown buffer, for the breadcrumb and the outline: each
-- { row (0-based), level (number of #s), text (plain) }, in order. Not "# ..."
-- lines in fenced code or >> blocks. Worked out again only after a change.

local M = {}

local cache = {} -- by buffer: { tick, list }

function M.list(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if cache[buf] and cache[buf].tick == tick then return cache[buf].list end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local skip = {}
  for _, block in ipairs(require("notedown.notes.blocks").find_blocks(lines)) do
    for row = block.first, block.last do skip[row] = true end
  end
  local plain = require("notedown.notes.heading_images").plain

  local list, fence = {}, nil
  for i, line in ipairs(lines) do
    local row = i - 1
    local marker = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if marker then
      if not fence then
        fence = marker
      elseif marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        fence = nil
      end
    elseif not fence and not skip[row] then
      local hashes, text = line:match("^(#+)%s+(.-)%s*$")
      if hashes and #hashes <= 6 then
        list[#list + 1] = { row = row, level = #hashes, text = plain(text) }
      end
    end
  end
  cache[buf] = { tick = tick, list = list }
  return list
end

-- The index in list of the heading of the section holding row (0-based), or
-- nil before the first heading.
function M.current(list, row)
  local index
  for i, heading in ipairs(list) do
    if heading.row > row then break end
    index = i
  end
  return index
end

vim.api.nvim_create_autocmd("BufWipeout", {
  group = vim.api.nvim_create_augroup("notedown.notes.headings", { clear = true }),
  callback = function(ev) cache[ev.buf] = nil end,
})

return M
