local icons = require('notedown.lib.icons')

---@alias notedown.health.Language
---| 'markdown'
---| 'markdown_inline'

---@class notedown.Health
local M = {}

---@private
M.version = '0.1.0'

function M.check()
    M.start('versions')
    M.neovim('0.11', '0.11')
    vim.health.ok('tree-sitter ABI: ' .. vim.treesitter.language_version)
    vim.health.ok('plugin: ' .. M.version)

    M.ts_info('markdown', true)
    M.ts_info('markdown_inline', false)

    M.start('icons')
    local provider = icons.name()
    if provider then
        vim.health.ok('using: ' .. provider)
    else
        vim.health.warn('none installed')
    end
end

---@private
---@param name string
function M.start(name)
    vim.health.start(('notedown [%s]'):format(name))
end

---@private
---@param min string
---@param rec string
function M.neovim(min, rec)
    if vim.fn.has('nvim-' .. min) == 0 then
        vim.health.error('neovim < ' .. min)
    elseif vim.fn.has('nvim-' .. rec) == 0 then
        vim.health.warn('neovim < ' .. rec .. ' some features will not work')
    else
        vim.health.ok('neovim >= ' .. rec)
    end
end

---@private
---@param language notedown.health.Language
---@param active boolean
function M.ts_info(language, active)
    M.start('tree-sitter ' .. language)

    local has_parser, parser = pcall(vim.treesitter.get_parser, 0, language)
    if has_parser and parser then
        vim.health.ok('parser: installed')
    else
        vim.health.error('parser: not installed')
    end

    local has_info, info = pcall(vim.treesitter.language.inspect, language)
    if has_info and info then
        vim.health.ok('ABI: ' .. info.abi_version)
    else
        vim.health.error('ABI: unknown')
    end

    local files = vim.treesitter.query.get_files(language, 'highlights')
    if #files > 0 then
        for _, file in ipairs(files) do
            local path = vim.fn.fnamemodify(file, ':~')
            vim.health.ok('highlights: ' .. path)
        end
    else
        vim.health.error('highlights: unknown')
    end

    if active then
        -- create a temporary buffer to check if vim.treesitter.start gets called
        local buf = vim.api.nvim_create_buf(false, true)
        vim.bo[buf].filetype = language
        local ok = vim.treesitter.highlighter.active[buf] ~= nil
        vim.api.nvim_buf_delete(buf, { force = true })
        if ok then
            vim.health.ok('highlighter: enabled')
        else
            vim.health.error('highlighter: not enabled', {
                ('call vim.treesitter.start() on %s buffers'):format(language),
            })
        end
    end
end

return M
