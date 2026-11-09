local str = require('notedown.lib.str')

---@class notedown.request.inline.Value
---@field col integer
---@field line notedown.mark.Line

---@class notedown.request.Inline
---@field private values table<integer, notedown.request.inline.Value[]>
local Inline = {}
Inline.__index = Inline

---@return notedown.request.Inline
function Inline.new()
    local self = setmetatable({}, Inline)
    self.values = {}
    return self
end

---@param row integer
---@param value notedown.request.inline.Value
function Inline:add(row, value)
    if #value.line == 0 then
        return
    end
    if not self.values[row] then
        self.values[row] = {}
    end
    local values = self.values[row]
    values[#values + 1] = value
end

---@param body notedown.node.Body
---@return integer
function Inline:width(body)
    local result = 0
    for _, value in ipairs(self:get(body)) do
        result = result + str.line_width(value.line)
    end
    return result
end

---@param body notedown.node.Body
---@param include_end? boolean
---@return notedown.request.inline.Value[]
function Inline:get(body, include_end)
    local result = {} ---@type notedown.request.inline.Value[]
    local values = self.values[body.start_row] or {}
    for _, value in ipairs(values) do
        local end_col = body.end_col + (include_end and 1 or 0)
        if value.col >= body.start_col and value.col < end_col then
            result[#result + 1] = value
        end
    end
    return result
end

return Inline
