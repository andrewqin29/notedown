local env = require('notedown.lib.env')

---@class notedown.resolved.Config
---@field private modes notedown.Modes
---@field private checkboxes table<string, notedown.checkbox.custom.Config>
local Resolved = {}
Resolved.__index = Resolved

---@param config notedown.partial.Config
---@return notedown.resolved.Config
function Resolved.new(config)
    local self = setmetatable({}, Resolved)
    -- super set of render modes across top level and individual components
    self.modes = config.render_modes
    local components = config ---@type table<string, notedown.base.Config>
    for _, component in pairs(components) do
        if type(component) == 'table' then
            self.modes = env.mode.join(self.modes, component.render_modes)
        end
    end
    self.checkboxes = Resolved.normalize(config.checkbox.custom)
    return self
end

---@private
---@generic T: notedown.raw.Config
---@param configs table<string, T>
---@return table<string, T>
function Resolved.normalize(configs)
    local result = {} ---@type table<string, any>
    for _, config in pairs(configs) do
        result[config.raw:lower()] = config
    end
    return result
end

---@param mode string
---@return boolean
function Resolved:render(mode)
    return env.mode.is(mode, self.modes)
end

---@param node notedown.Node
---@return notedown.checkbox.custom.Config?
function Resolved:checkbox(node)
    return self.checkboxes[node.text:lower()]
end

return Resolved
