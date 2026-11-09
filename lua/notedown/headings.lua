-- The headings of a markdown buffer, for the breadcrumb and the outline: each
-- { row (0-based), level (number of #s), text (plain) }, in order. Not "# ..."
-- lines in fenced code or >> blocks. Worked out again only after a change.

local M = {}

local cache = {} -- by buffer: { tick, list }

function M.list(buf)
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  if cache[buf] and cache[buf].tick == tick then return cache[buf].list end

  local scan = require("notedown.blocks").scan(buf)
  local plain = require("notedown.heading_images").plain
  local list = {}
  for i, line in ipairs(scan.lines) do
    local row = i - 1
    if not scan.fenced[row] and not scan.block[row] then
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
  group = vim.api.nvim_create_augroup("notedown.headings", { clear = true }),
  callback = function(ev) cache[ev.buf] = nil end,
})

return M
