local settings = require('notedown.settings')

---@class notedown.Init: notedown.Api
local M = {}

---@class (exact) notedown.Config: notedown.partial.Config
---@field log_level notedown.log.Level
---@field log_runtime boolean

---The parts of the config a buffer has its own copy of.
---@class (exact) notedown.partial.Config: notedown.base.Config
---@field debounce integer
---@field anti_conceal notedown.anti.conceal.Config
---@field bullet notedown.bullet.Config
---@field checkbox notedown.checkbox.Config
---@field dash notedown.dash.Config
---@field heading notedown.heading.Config
---@field inline_highlight notedown.inline.highlight.Config
---@field padding notedown.padding.Config
---@field pipe_table notedown.table.Config
---@field quote notedown.quote.Config
---@field win_options notedown.window.Configs

---Any part of notedown.Config, merged into the defaults.
---@alias notedown.UserConfig table

---@private
---@type boolean
M.initialized = false

---@type notedown.Config
M.default = {
    -- Whether markdown is rendered.
    enabled = true,
    -- Modes that show the rendered view (:h mode()); other modes show the text
    -- as typed.
    render_modes = { 'n', 'c', 't' },
    -- Milliseconds to wait after a change before rendering again.
    debounce = 100,
    -- Logs to vim.fn.stdpath('state') .. '/notedown.log', for development.
    log_level = 'error',
    -- Log how long each render takes, for development.
    log_runtime = false,
    anti_conceal = settings.anti_conceal,
    bullet = settings.bullet,
    checkbox = settings.checkbox,
    dash = settings.dash,
    heading = settings.heading,
    inline_highlight = settings.inline_highlight,
    padding = settings.padding,
    pipe_table = settings.pipe_table,
    quote = settings.quote,
    win_options = settings.win_options,
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
    return vim.tbl_deep_extend('force', M.default, user)
end

return setmetatable(M, {
    __index = function(_, key)
        -- Allows API methods to be accessed from top level
        return require('notedown.api')[key]
    end,
})
