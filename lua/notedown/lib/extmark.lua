local interval = require('notedown.lib.interval')

---@class notedown.Extmark
---@field private id? integer
---@field private mark notedown.Mark
---@field private range notedown.Range
local Extmark = {}
Extmark.__index = Extmark

---@param mark notedown.Mark
---@return notedown.Extmark
function Extmark.new(mark)
    local self = setmetatable({}, Extmark)
    self.id = nil
    self.mark = mark
    local top = mark.start_row
    local bottom = mark.opts.end_row or top
    -- hl_eol should not include last line
    if mark.opts.hl_eol then
        bottom = bottom - 1
    end
    self.range = { top, bottom }
    return self
end

---@return notedown.Mark
function Extmark:get()
    return self.mark
end

---@param range? notedown.Range
---@return boolean
function Extmark:overlaps(range)
    if not range then
        return false
    end
    return interval.overlap(self.range, range) ~= nil
end

---@param ns integer
---@param buf integer
function Extmark:show(ns, buf)
    if self.id then
        return
    end
    local mark = self.mark
    mark.opts.strict = false
    local ok, id = pcall(
        vim.api.nvim_buf_set_extmark,
        buf,
        ns,
        mark.start_row,
        mark.start_col,
        mark.opts
    )
    if ok then
        self.id = id
    else
        local compat = require('notedown.lib.compat')
        compat.release(('nvim_buf_set_extmark error (%s)'):format(id))
    end
end

---@param ns integer
---@param buf integer
function Extmark:hide(ns, buf)
    if not self.id then
        return
    end
    vim.api.nvim_buf_del_extmark(buf, ns, self.id)
    self.id = nil
end

return Extmark
