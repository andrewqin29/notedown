---@class notedown.Presets
local M = {}

---@param user notedown.UserConfig
---@return notedown.UserConfig
function M.get(user)
    return M.partial(user) or {}
end

---@private
---@param user? notedown.partial.UserConfig?
---@return notedown.partial.UserConfig?
function M.partial(user)
    if type(user) ~= 'table' then
        return nil
    end
    ---@type notedown.partial.UserConfig
    return {
        pipe_table = M.pipe_table(user),
        win_options = M.win_options(user),
    }
end

---@private
---@param user notedown.partial.UserConfig
---@return notedown.table.UserConfig?
function M.pipe_table(user)
    ---@type table<notedown.table.Preset?, notedown.table.UserConfig?>
    local presets = {
        ['round'] = {
            -- stylua: ignore
            border = {
                '╭', '┬', '╮',
                '├', '┼', '┤',
                '╰', '┴', '╯',
                '│', '─',
            },
        },
        ['double'] = {
            -- stylua: ignore
            border = {
                '╔', '╦', '╗',
                '╠', '╬', '╣',
                '╚', '╩', '╝',
                '║', '═',
            },
        },
        ['heavy'] = {
            alignment_indicator = '─',
            -- stylua: ignore
            border = {
                '┏', '┳', '┓',
                '┣', '╋', '┫',
                '┗', '┻', '┛',
                '┃', '━',
            },
        },
    }
    ---@type table<notedown.table.Style?, notedown.table.UserConfig?>
    local styles = {
        ['none'] = { enabled = false },
        ['normal'] = { border_enabled = false },
    }
    local preset = presets[(user.pipe_table or {}).preset] or {}
    local style = styles[(user.pipe_table or {}).style] or {}
    local result = vim.tbl_deep_extend('force', preset, style)
    return vim.tbl_count(result) > 0 and result or nil
end

---@private
---@param user notedown.partial.UserConfig
---@return notedown.window.UserConfigs?
function M.win_options(user)
    ---@type table<boolean?, notedown.window.UserConfigs?>
    local anti_conceals = {
        [false] = { concealcursor = { rendered = 'nvic' } },
    }
    return anti_conceals[(user.anti_conceal or {}).enabled]
end

return M
