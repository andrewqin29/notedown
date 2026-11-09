local Indent = require('notedown.lib.indent')
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

---@protected
---@return notedown.Indent
function Base:indent()
    return Indent.new(self.context, self.node)
end

---@protected
---@param config notedown.base.Config
---@param enabled boolean
---@param text? string
---@param highlight? string
function Base:sign(config, enabled, text, highlight)
    local sign = self.context.config.sign
    if not enabled or not text or not sign.enabled then
        return
    end
    local sign_highlight = sign.highlight
    if highlight then
        sign_highlight = colors.combine(highlight, sign_highlight)
    end
    self.marks:start(config, 'sign', self.node, {
        priority = sign.priority,
        sign_text = text,
        sign_hl_group = sign_highlight,
    })
end

return Base
