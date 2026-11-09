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

    -- reset cache
    M.cache = {}

    require('notedown.core.ui').setup()
end

---@param buf integer
---@return notedown.buf.Config
function M.get(buf)
    if not M.cache[buf] then
        M.cache[buf] = Config.new(M.config, M.enabled)
    end
    return assert(M.cache[buf], 'missing buffer config')
end

---@param buf integer
---@return notedown.buf.Config?
function M.get_config(buf)
    return M.cache[buf]
end

return M
