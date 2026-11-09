local Line = require('notedown.lib.line')
local Resolved = require('notedown.lib.resolved')
local iter = require('notedown.lib.iter')

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
        document = root.document,
        heading = root.heading,
        inline_highlight = root.inline_highlight,
        padding = root.padding,
        paragraph = root.paragraph,
        pipe_table = root.pipe_table,
        quote = root.quote,
        render = root.render,
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

---@param child notedown.schema.Record
---@return notedown.Schema
function Config.schema(child)
    local settings = require('notedown.settings')
    ---@type notedown.schema.Record
    local parent = {
        debounce = { type = 'number' },
        anti_conceal = settings.anti_conceal.schema(),
        bullet = settings.bullet.schema(),
        checkbox = settings.checkbox.schema(),
        dash = settings.dash.schema(),
        document = settings.document.schema(),
        heading = settings.heading.schema(),
        inline_highlight = settings.inline_highlight.schema(),
        padding = settings.padding.schema(),
        paragraph = settings.paragraph.schema(),
        pipe_table = settings.pipe_table.schema(),
        quote = settings.quote.schema(),
        render = settings.render.schema(),
        win_options = settings.win_options.schema(),
    }
    local record = vim.tbl_deep_extend('error', parent, child)
    return settings.base.schema(record)
end

return Config
