---@class notedown.request.checkbox.Value
---@field node notedown.Node
---@field config notedown.checkbox.component.Config

---@class notedown.request.Checkbox
---@field private values table<integer, notedown.request.checkbox.Value>
local Checkbox = {}
Checkbox.__index = Checkbox

---@return notedown.request.Checkbox
function Checkbox.new()
    local self = setmetatable({}, Checkbox)
    self.values = {}
    return self
end

---@param node notedown.Node
---@param config notedown.checkbox.custom.Config
function Checkbox:set(node, config)
    self.values[node.start_row] = {
        node = node,
        config = {
            icon = config.rendered,
            highlight = config.highlight,
            scope_highlight = config.scope_highlight,
        },
    }
end

---@param node notedown.Node
---@return notedown.request.checkbox.Value?
function Checkbox:get(node)
    return self.values[node.start_row]
end

return Checkbox
