---@class notedown.render.Context
---@field buf integer
---@field win? integer|integer[]
---@field event? string
---@field force? boolean
---@field config? notedown.partial.UserConfig

---@class notedown.Api
local M = {}

---@param ctx notedown.render.Context
function M.render(ctx)
    local env = require('notedown.lib.env')
    local list = require('notedown.lib.list')
    local state = require('notedown.state')
    local ui = require('notedown.core.ui')

    local buf = ctx.buf
    local wins = list.ensure(ctx.win or env.buf.wins(buf))
    local event = ctx.event or 'Api'
    local force = ctx.force ~= false

    state.get(buf, ctx.config)
    state.attach()

    for _, win in ipairs(wins) do
        ui.update(buf, win, event, force)
    end
end

---@param buf? integer
---@return boolean
function M.get(buf)
    local state = require('notedown.state')

    if buf then
        local config = state.get_config(buf)
        return config and config.enabled or false
    else
        return state.enabled
    end
end

---@param enable? boolean
function M.set(enable)
    require('notedown.core.manager').set(enable)
end

---@param enable? boolean
function M.set_buf(enable)
    require('notedown.core.manager').set_buf(nil, enable)
end

function M.enable()
    M.set(true)
end

function M.buf_enable()
    M.set_buf(true)
end

function M.disable()
    M.set(false)
end

function M.buf_disable()
    M.set_buf(false)
end

function M.toggle()
    M.set()
end

function M.buf_toggle()
    M.set_buf()
end

function M.preview()
    require('notedown.core.preview').open()
end

function M.log()
    require('notedown.core.log').open()
end

function M.expand()
    require('notedown.state').modify_anti_conceal(1)
    M.enable()
end

function M.contract()
    require('notedown.state').modify_anti_conceal(-1)
    M.enable()
end

function M.debug()
    require('notedown.debug.marks').show()
end

function M.config()
    local difference = require('notedown.state').difference()
    if not difference then
        -- selene: allow(deprecated)
        vim.print('default configuration')
    else
        -- selene: allow(deprecated)
        vim.print(difference)
    end
end

return M
