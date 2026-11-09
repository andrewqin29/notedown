local settings = require('notedown.settings')

---@class notedown.Init: notedown.Api
local M = {}

---@class (exact) notedown.Config: notedown.partial.Config, notedown.state.Config
---@field overrides notedown.overrides.Config

---@class (exact) notedown.partial.Config: notedown.base.Config
---@field debounce integer
---@field anti_conceal notedown.anti.conceal.Config
---@field bullet notedown.bullet.Config
---@field checkbox notedown.checkbox.Config
---@field dash notedown.dash.Config
---@field document notedown.document.Config
---@field heading notedown.heading.Config
---@field html notedown.html.Config
---@field indent notedown.indent.Config
---@field inline_highlight notedown.inline.highlight.Config
---@field link notedown.link.Config
---@field padding notedown.padding.Config
---@field paragraph notedown.paragraph.Config
---@field pipe_table notedown.table.Config
---@field quote notedown.quote.Config
---@field render notedown.render.Config
---@field sign notedown.sign.Config
---@field win_options notedown.window.Configs
---@field yaml notedown.yaml.Config

---@class (exact) notedown.state.Config
---@field log_level notedown.log.Level
---@field log_runtime boolean
---@field notes boolean
---@field file_types string[]
---@field max_file_size number
---@field ignore fun(buf: integer): boolean
---@field nested boolean
---@field change_events string[]
---@field restart_highlighter boolean
---@field injections notedown.injection.Configs
---@field patterns notedown.pattern.Configs
---@field on notedown.on.Config
---@field custom_handlers table<string, notedown.Handler>

---@private
---@type boolean
M.initialized = false

---@type notedown.Config
M.default = {
    -- Whether markdown should be rendered by default.
    enabled = true,
    -- Vim modes that will show a rendered view of the markdown file, :h mode(), for all enabled
    -- components. Individual components can be enabled for other modes. Remaining modes will be
    -- unaffected by this plugin.
    render_modes = { 'n', 'c', 't' },
    -- Milliseconds that must pass before updating marks, updates occur.
    -- within the context of the visible window, not the entire buffer.
    debounce = 100,
    -- Pre configured settings that will attempt to mimic various target user experiences.
    -- User provided settings will take precedence.
    -- | obsidian | mimic Obsidian UI                                          |
    -- | lazy     | will attempt to stay up to date with LazyVim configuration |
    -- | none     | does nothing                                               |
    -- The level of logs to write to file: vim.fn.stdpath('state') .. '/notedown.log'.
    -- Only intended to be used for plugin development / debugging.
    log_level = 'error',
    -- Print runtime of main update method.
    -- Only intended to be used for plugin development / debugging.
    log_runtime = false,
    -- Filetypes this plugin will run on.
    -- Render the note format (notes/), on top of plain markdown rendering.
    notes = true,
    file_types = { 'markdown' },
    -- Maximum file size (in MB) that this plugin will attempt to render.
    -- File larger than this will effectively be ignored.
    max_file_size = 10.0,
    -- Takes buffer as input, if it returns true this plugin will not attach to the buffer.
    ignore = function()
        return false
    end,
    -- Whether markdown should be rendered when nested inside markdown, i.e. markdown code block
    -- inside markdown file.
    nested = true,
    -- Additional events that will trigger this plugin's render loop.
    change_events = {},
    -- Whether the treesitter highlighter should be restarted after this plugin attaches to its
    -- first buffer for the first time. May be necessary if this plugin is lazy loaded to clear
    -- highlights that have been dynamically disabled.
    restart_highlighter = false,
    injections = settings.injections.default,
    patterns = settings.patterns.default,
    anti_conceal = settings.anti_conceal.default,
    padding = settings.padding.default,
    on = settings.on.default,
    heading = settings.heading.default,
    paragraph = settings.paragraph.default,
    dash = settings.dash.default,
    document = settings.document.default,
    bullet = settings.bullet.default,
    checkbox = settings.checkbox.default,
    quote = settings.quote.default,
    render = settings.render.default,
    pipe_table = settings.pipe_table.default,
    link = settings.link.default,
    sign = settings.sign.default,
    inline_highlight = settings.inline_highlight.default,
    indent = settings.indent.default,
    html = settings.html.default,
    win_options = settings.win_options.default,
    overrides = settings.overrides.default,
    custom_handlers = settings.handlers.default,
    yaml = settings.yaml.default,
}

---@param opts? notedown.UserConfig
function M.setup(opts)
    -- This handles discrepancies in initialization order of different plugin managers, some
    -- run the plugin directory first (lazy.nvim) while others run setup first (vim-plug).
    -- To support both we want to pickup the last non-empty configuration. This works because
    -- the plugin directory supplies an empty configuration which will be skipped if state
    -- has already been initialized by the user.
    if M.initialized and vim.tbl_count(opts or {}) == 0 then
        return
    end
    M.initialized = true
    local config = M.resolve_config(opts or {})
    require('notedown.state').setup(config)
end

---@private
---@param user notedown.UserConfig
---@return notedown.Config
function M.resolve_config(user)
    local preset = require('notedown.lib.presets').get(user)
    -- the note format's settings (notes/init.lua) apply under the user's
    local notes = user.notes ~= false and require('notedown.notes').defaults or {}
    local config = vim.tbl_deep_extend('force', M.default, notes, preset, user)

    -- override settings that are incompatible with neovim version

    -- override settings that are incompatible with other settings
    if config.indent.enabled then
        config.pipe_table.border_virtual = true
    end
    if vim.tbl_contains({ 'raw', 'overlay' }, config.pipe_table.cell) then
        config.pipe_table.wrap = false
    end

    -- use lazy.nvim file type configuration if available and no user value is specified
    if not user.file_types then
        local lazy_file_types = require('notedown.lib.env').lazy('ft')
        if #lazy_file_types > 0 then
            config.file_types = lazy_file_types
        end
    end

    return config
end

return setmetatable(M, {
    __index = function(_, key)
        -- Allows API methods to be accessed from top level
        return require('notedown.api')[key]
    end,
})
