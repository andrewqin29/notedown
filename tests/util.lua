---@module 'luassert'

---@class notedown.test.Util
local M = {}

---@class notedown.test.util.Setup
M.setup = {}

---@private
---@param opts? notedown.UserConfig
function M.setup.init(opts)
    require('luassert.assert'):set_parameter('TableFormatLevel', 4)
    require('luassert.assert'):set_parameter('TableErrorHighlightColor', 'none')
    ---@type notedown.UserConfig
    local test_config = {
        anti_conceal = { enabled = false },
        win_options = { concealcursor = { rendered = 'nvic' } },
    }
    local config = vim.tbl_deep_extend('force', test_config, opts or {})
    require('notedown').setup(config)
end

---@param file string
---@param opts? notedown.UserConfig
function M.setup.file(file, opts)
    M.setup.init(opts)
    vim.cmd('e ' .. file)
    vim.wait(0)
    M.no_breadcrumb()
end

---@param lines string[]
---@param opts? notedown.UserConfig
function M.setup.text(lines, opts)
    M.setup.init(opts)
    -- a file buffer (not scratch): notedown only renders files. Marked as
    -- saved, so the next test can switch away from it.
    vim.bo.modified = false
    local buf = vim.api.nvim_create_buf(false, false)
    vim.bo[buf].bufhidden = 'wipe'
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    vim.bo[buf].filetype = 'markdown'
    vim.wait(0)
    M.no_breadcrumb()
end

---The breadcrumb (notes/breadcrumb.lua) isn't part of what these tests check,
---and its scroll percentage would change with the cursor.
function M.no_breadcrumb()
    vim.wo.winbar = ''
    vim.cmd('redraw')
end

---@param row integer
---@param scroll_to_top? boolean
function M.set_row(row, scroll_to_top)
    vim.api.nvim_win_set_cursor(0, { row, 0 })
    if scroll_to_top then
        vim.cmd('normal! zt')
    end
    vim.api.nvim_exec_autocmds('CursorMoved', {})
    vim.wait(0)
end

---@param expected string[]
function M.assert_screen(expected)
    local actual = M.actual_screen()
    assert.same(expected, actual)
end

---@private
---@return string[]
function M.actual_screen()
    vim.cmd('redraw')

    local actual = {} ---@type string[]
    for row = 1, vim.o.lines do
        local line = ''
        for col = 1, vim.o.columns do
            line = line .. vim.fn.screenstring(row, col)
        end
        -- trailing whitespace dropped to make expectations easier to write
        line = line:gsub('%s+$', '')
        -- the end of the buffer
        if line == '~' then
            break
        end
        actual[#actual + 1] = line
    end
    return actual
end

return M
