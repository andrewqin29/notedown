local env = require('notedown.lib.env')

---@class notedown.resolved.Config
---@field private modes notedown.Modes
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
    return self
end

---@param mode string
---@return boolean
function Resolved:render(mode)
    return env.mode.is(mode, self.modes)
end

return Resolved
