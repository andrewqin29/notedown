---@class notedown.test.Row
---@field private value integer
local Row = {}
Row.__index = Row

---@return notedown.test.Row
function Row.new()
    local self = setmetatable({}, Row)
    self.value = 0
    return self
end

---@param soff integer
---@param eoff? integer
---@return notedown.test.Range
function Row:get(soff, eoff)
    ---@type notedown.test.Range
    return { self:inc(soff), eoff and self:inc(eoff) or nil }
end

---@private
---@param n integer
---@return integer
function Row:inc(n)
    self.value = self.value + n
    return self.value
end

return Row
