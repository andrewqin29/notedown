local env = require('notedown.lib.env')
local log = require('notedown.core.log')
local state = require('notedown.state')
local ui = require('notedown.core.ui')

---@class notedown.Manager
local M = {}

---@private
M.group = vim.api.nvim_create_augroup('Notedown', {})

---@private
---@type integer[]
M.buffers = {}

---called from plugin directory
function M.init()
    M.attach(env.buf.current())
    -- attempt to attach to all buffers, cannot use pattern to support plugin directory
    vim.api.nvim_create_autocmd('FileType', {
        group = M.group,
        callback = function(args)
            M.attach(args.buf)
        end,
    })
    -- window resizing is not buffer specific so is managed more globally
    vim.api.nvim_create_autocmd('WinResized', {
        group = M.group,
        callback = function(args)
            for _, win in ipairs(vim.v.event.windows or {}) do
                local buf = env.win.buf(win)
                if M.attached(buf) and state.get(buf).enabled then
                    ui.update(buf, win, args.event, true)
                end
            end
        end,
    })
end

---@param buf integer
---@return boolean
function M.attached(buf)
    return vim.tbl_contains(M.buffers, buf)
end

---@param enable? boolean
function M.set(enable)
    if enable ~= nil then
        state.enabled = enable
    else
        state.enabled = not state.enabled
    end
    for _, buf in ipairs(M.buffers) do
        M.set_buf(buf, state.enabled)
    end
end

---@param buf? integer
---@param enable? boolean
function M.set_buf(buf, enable)
    buf = buf or env.buf.current()
    if M.attached(buf) then
        local config = state.get(buf)
        if enable ~= nil then
            config.enabled = enable
        else
            config.enabled = not config.enabled
        end
        ui.update(buf, env.buf.win(buf), 'UserCommand', true)
    end
end

---@private
---@param buf integer
function M.attach(buf)
    if not M.should_attach(buf) then
        return
    end

    local config = state.get(buf)

    local events = {
        'BufWinEnter',
        'BufLeave',
        'CmdlineChanged',
        'CursorHold',
        'CursorMoved',
        'DiffUpdated',
        'ModeChanged',
        'TextChanged',
        'WinScrolled',
    }
    if config.resolved:render('i') then
        events[#events + 1] = 'CursorHoldI'
        events[#events + 1] = 'CursorMovedI'
        events[#events + 1] = 'TextChangedI'
    end

    vim.api.nvim_create_autocmd(events, {
        group = M.group,
        buffer = buf,
        callback = function(args)
            if not state.get(buf).enabled then
                return
            end
            local win = env.buf.win(buf)
            local event = args.event
            ui.update(buf, win, event, false)
        end,
    })

    if config.enabled then
        ui.update(buf, env.buf.win(buf), 'Initial', true)
    end
end

---@private
---@param buf integer
---@return boolean
function M.should_attach(buf)
    log.attach(buf, 'start')

    if M.attached(buf) then
        log.attach(buf, 'skip', 'already attached')
        return false
    end

    if not vim.api.nvim_buf_is_valid(buf) then
        log.attach(buf, 'skip', 'invalid')
        return false
    end

    -- markdown files only: not other buffers holding markdown, such as LSP
    -- hover popups and plugin windows (their buftype isn't empty)
    if env.buf.get(buf, 'filetype') ~= 'markdown' then
        log.attach(buf, 'skip', 'not markdown')
        return false
    end
    if env.buf.get(buf, 'buftype') ~= '' then
        log.attach(buf, 'skip', 'not a file')
        return false
    end

    log.attach(buf, 'success')
    M.buffers[#M.buffers + 1] = buf
    return true
end

return M
