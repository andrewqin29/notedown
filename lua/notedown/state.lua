local Config = require('notedown.lib.config')

---@class notedown.State: notedown.state.Config
---@field private config notedown.Config
---@field enabled boolean
local M = {}

---@private
---@type table<integer, notedown.buf.Config>
M.cache = {}

---called from init on setup
---@param config notedown.Config
function M.setup(config)
    M.config = config
    M.enabled = config.enabled
    M.log_level = config.log_level
    M.log_runtime = config.log_runtime
    M.file_types = config.file_types
    M.notes = config.notes
    M.max_file_size = config.max_file_size
    M.ignore = config.ignore
    M.nested = config.nested
    M.change_events = config.change_events
    M.restart_highlighter = config.restart_highlighter
    M.injections = config.injections
    M.patterns = config.patterns
    M.on = config.on
    M.custom_handlers = config.custom_handlers

    -- reset cache
    M.cache = {}

    require('notedown.core.ts').setup()
    require('notedown.core.ui').setup()
end

---@param buf integer
---@param custom? notedown.partial.UserConfig
---@return notedown.buf.Config
function M.get(buf, custom)
    if not M.cache[buf] then
        M.cache[buf] = Config.new(M.config, M.enabled, buf, custom)
    end
    return assert(M.cache[buf], 'missing buffer config')
end

---@param buf integer
---@return notedown.buf.Config?
function M.get_config(buf)
    return M.cache[buf]
end

function M.attach()
    require('notedown.core.ts').init()
end

---@param amount integer
function M.modify_anti_conceal(amount)
    ---@param config notedown.anti.conceal.Config
    local function modify(config)
        config.above = math.max(config.above + amount, 0)
        config.below = math.max(config.below + amount, 0)
    end
    modify(M.config.anti_conceal)
    for _, config in pairs(M.cache) do
        modify(config.anti_conceal)
    end
end

---@return table?
function M.difference()
    local default = require('notedown').default
    return require('notedown.debug.diff').get(default, M.config)
end

---@return string[]
function M.validate()
    local settings = require('notedown.settings')
    return require('notedown.debug.schema').validate(
        M.config,
        Config.schema({
            log_level = {
                enum = { 'trace', 'debug', 'info', 'warn', 'error', 'off' },
            },
            log_runtime = { type = 'boolean' },
            notes = { type = 'boolean' },
            file_types = { list = { type = 'string' } },
            max_file_size = { type = 'number' },
            ignore = { type = 'function' },
            nested = { type = 'boolean' },
            change_events = { list = { type = 'string' } },
            restart_highlighter = { type = 'boolean' },
            injections = settings.injections.schema(),
            patterns = settings.patterns.schema(),
            on = settings.on.schema(),
            overrides = settings.overrides.schema(),
            custom_handlers = settings.handlers.schema(),
        })
    )
end

return M
