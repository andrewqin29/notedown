local Line = require('notedown.lib.line')
local Resolved = require('notedown.lib.resolved')
local env = require('notedown.lib.env')
local iter = require('notedown.lib.iter')

---@class notedown.buf.Config: notedown.partial.Config
---@field resolved notedown.resolved.Config
local Config = {}
Config.__index = Config

---@param root notedown.Config
---@param enabled boolean
---@param buf integer
---@param custom? notedown.partial.UserConfig
---@return notedown.buf.Config
function Config.new(root, enabled, buf, custom)
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
        html = root.html,
        indent = root.indent,
        inline_highlight = root.inline_highlight,
        link = root.link,
        padding = root.padding,
        paragraph = root.paragraph,
        pipe_table = root.pipe_table,
        quote = root.quote,
        render = root.render,
        sign = root.sign,
        win_options = root.win_options,
        yaml = root.yaml,
    }
    config = vim.deepcopy(config)

    ---@param override? notedown.partial.UserConfig
    local function extend(override)
        config = vim.tbl_deep_extend('force', config, override or {})
    end

    local src = require('notedown.core.preview').get(buf)
    extend(root.overrides.buflisted[env.buf.get(src or buf, 'buflisted')])
    extend(root.overrides.buftype[env.buf.get(src or buf, 'buftype')])
    extend(root.overrides.filetype[env.buf.get(src or buf, 'filetype')])
    extend(src and root.overrides.preview)
    extend(custom)

    local self = setmetatable(config, Config)
    self.resolved = Resolved.new(config)
    ---@cast self -notedown.partial.Config
    return self
end

---@return notedown.Line
function Config:line()
    return Line.new(self.padding.highlight)
end

---@param destination string
---@param icon notedown.mark.Text
function Config:set_link_text(destination, icon)
    local options = iter.table.filter(self.link.custom, function(custom)
        if custom.kind == 'suffix' then
            return vim.endswith(destination, custom.pattern)
        elseif custom.kind == 'prefix' then
            return vim.startswith(destination, custom.pattern)
        elseif custom.kind == 'url' then
            local prefix = destination:match('^(.*)' .. custom.pattern) ---@type string?
            if not prefix then
                return false
            end
            prefix = prefix:gsub('^https?://', '', 1)
            prefix = prefix:gsub('^www%.', '', 1)
            local last = prefix:sub(-1)
            return last == '' or last == '.'
        else
            return destination:find(custom.pattern) ~= nil
        end
    end)
    iter.list.sort(options, function(custom)
        return custom.priority or #custom.pattern
    end)
    local result = options[#options]
    if result then
        icon[1] = result.icon
        icon[2] = result.highlight or icon[2]
    end
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
        html = settings.html.schema(),
        indent = settings.indent.schema(),
        inline_highlight = settings.inline_highlight.schema(),
        link = settings.link.schema(),
        padding = settings.padding.schema(),
        paragraph = settings.paragraph.schema(),
        pipe_table = settings.pipe_table.schema(),
        quote = settings.quote.schema(),
        render = settings.render.schema(),
        sign = settings.sign.schema(),
        win_options = settings.win_options.schema(),
        yaml = settings.yaml.schema(),
    }
    local record = vim.tbl_deep_extend('error', parent, child)
    return settings.base.schema(record)
end

return Config
