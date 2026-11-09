local colors = require('notedown.core.colors')

---@class notedown.Render
---@field protected context notedown.request.Context
---@field protected marks notedown.Marks
---@field protected node notedown.Node
local Base = {}
Base.__index = Base

---@param context notedown.request.Context
---@param marks notedown.Marks
---@param node notedown.Node
---@return boolean
function Base:execute(context, marks, node)
    local instance = setmetatable({}, self)
    instance.context = context
    instance.marks = marks
    instance.node = node
    if instance:setup() then
        instance:run()
        return true
    else
        return false
    end
end

---@protected
---@return boolean
function Base:setup()
    error('unimplemented', 2)
end

---@protected
function Base:run()
    error('unimplemented', 2)
end

---@protected
---@return notedown.Line
function Base:line()
    return self.context.config:line()
end

return Base
