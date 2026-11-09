local Line = require('notedown.lib.line')
local Resolved = require('notedown.lib.resolved')

---@class notedown.buf.Config: notedown.partial.Config
---@field resolved notedown.resolved.Config
local Config = {}
Config.__index = Config

---@param root notedown.Config
---@param enabled boolean
---@return notedown.buf.Config
function Config.new(root, enabled)
    ---@type notedown.partial.Config
    local config = {
        enabled = enabled,
        render_modes = root.render_modes,
        debounce = root.debounce,
        anti_conceal = root.anti_conceal,
        bullet = root.bullet,
        checkbox = root.checkbox,
        dash = root.dash,
        heading = root.heading,
        inline_highlight = root.inline_highlight,
        padding = root.padding,
        pipe_table = root.pipe_table,
        quote = root.quote,
        win_options = root.win_options,
    }
    config = vim.deepcopy(config)

    local self = setmetatable(config, Config)
    self.resolved = Resolved.new(config)
    ---@cast self -notedown.partial.Config
    return self
end

---@return notedown.Line
function Config:line()
    return Line.new(self.padding.highlight)
end

return Config
