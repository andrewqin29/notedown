local Base = require('notedown.render.base')

---Thematic breaks (---): a line across the window.
---@class notedown.render.Dash: notedown.Render
---@field private config notedown.dash.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.dash
    return self.config.enabled
end

---@protected
function Render:run()
    local line = self:line():rep(self.config.icon, vim.o.columns, self.config.highlight)
    self.marks:add(self.config, 'dash', self.node.start_row, 0, {
        virt_text = line:get(),
        virt_text_pos = 'overlay',
    })
end

return Render
