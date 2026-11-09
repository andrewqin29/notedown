---@class notedown.Presets
local M = {}

---@param user notedown.UserConfig
---@return notedown.UserConfig
function M.get(user)
    return vim.tbl_deep_extend('force', M.partial(user) or {}, M.overrides(user))
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
---@param user notedown.UserConfig
---@return notedown.UserConfig
function M.overrides(user)
    ---@param configs? table<any, notedown.partial.UserConfig>
    ---@return table<any, notedown.partial.UserConfig>?
    local function partials(configs)
        if type(configs) ~= 'table' then
            return nil
        end
        local result = {} ---@type table<any, notedown.partial.UserConfig>
        for value, override in pairs(configs) do
            result[value] = M.partial(override)
        end
        return result
    end

    ---@type notedown.overrides.UserConfig
    local overrides = {
        buflisted = partials((user.overrides or {}).buflisted),
        buftype = partials((user.overrides or {}).buftype),
        filetype = partials((user.overrides or {}).filetype),
        preview = M.partial((user.overrides or {}).preview),
    }

    ---@type notedown.UserConfig
    return { overrides = vim.tbl_count(overrides) > 0 and overrides or nil }
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
