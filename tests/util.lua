---@module 'luassert'

---@class notedown.test.Range
---@field [1] integer
---@field [2]? integer

---@class notedown.test.MarkInfo: notedown.mark.Opts
---@field row notedown.test.Range
---@field col notedown.test.Range

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
        -- the plain markdown renderer: the note format has its own tests
        notes = false,
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
end

M.row = require('tests.helpers.row').new

M.marks = require('tests.helpers.marks').new

M.system = require('tests.helpers.system')

---@return vim.api.keyset.set_extmark
function M.conceal()
    ---@type vim.api.keyset.set_extmark
    return { conceal = '' }
end

---@return vim.api.keyset.set_extmark
function M.conceal_lines()
    ---@type vim.api.keyset.set_extmark
    return { conceal_lines = '' }
end

---@param kind 'inline'|'link'|'title'
---@return vim.api.keyset.set_extmark
function M.highlight(kind)
    local priority ---@type integer?
    local highlight ---@type string
    if kind == 'inline' then
        highlight = 'RmInlineHighlight'
    elseif kind == 'link' then
        priority = 1000
        highlight = 'RmLink'
    elseif kind == 'title' then
        priority = 1000
        highlight = 'RmLinkTitle'
    end
    ---@type vim.api.keyset.set_extmark
    return {
        priority = priority,
        hl_eol = false,
        hl_group = highlight,
    }
end

---@param kind 'checked'|'unchecked'|'todo'
---@param space integer
---@param icon? string
---@return vim.api.keyset.set_extmark
function M.checkbox(kind, space, icon)
    local line = {} ---@type notedown.mark.Line
    if kind == 'checked' then
        line[#line + 1] = { icon or '󰱒 ', 'RmChecked' }
    elseif kind == 'unchecked' then
        line[#line + 1] = { icon or '󰄱 ', 'RmUnchecked' }
    elseif kind == 'todo' then
        line[#line + 1] = { icon or '󰥔 ', 'RmTodo' }
    end
    if space > 0 then
        line[#line + 1] = { (' '):rep(space), 'RmPadding' }
    end
    ---@type vim.api.keyset.set_extmark
    return {
        hl_mode = 'combine',
        virt_text = line,
        virt_text_pos = 'overlay',
    }
end

---@param level integer
---@param spaces? integer
---@return vim.api.keyset.set_extmark
function M.bullet(level, spaces)
    local icons = { '●', '○', '◆', '◇' }
    ---@type vim.api.keyset.set_extmark
    return {
        virt_text = {
            { (' '):rep(spaces or 0) .. icons[level], 'RmBullet' },
        },
        virt_text_pos = 'overlay',
    }
end

---@param level integer
---@return vim.api.keyset.set_extmark
function M.ordered(level)
    ---@type vim.api.keyset.set_extmark
    return {
        virt_text = { { ('%d.'):format(level), 'RmBullet' } },
        virt_text_pos = 'overlay',
    }
end

---@param kind 'email'|'git'|'image'|'link'|'web'|'wiki'|'youtube'
---@return vim.api.keyset.set_extmark
function M.link(kind)
    local icons = {
        email = '󰀓 ',
        git = '󰊤 ',
        image = '󰥶 ',
        link = '󰌹 ',
        web = '󰖟 ',
        wiki = '󱗖 ',
        youtube = '󰗃 ',
    }
    local highlight = kind == 'wiki' and 'RmWikiLink' or 'RmLink'
    ---@type vim.api.keyset.set_extmark
    return {
        priority = 9000,
        hl_mode = 'combine',
        virt_text = { { icons[kind], highlight } },
        virt_text_pos = 'inline',
    }
end

---@param highlight string
---@return vim.api.keyset.set_extmark
function M.quote(highlight)
    ---@type vim.api.keyset.set_extmark
    return {
        virt_text = { { '▋', highlight } },
        virt_text_pos = 'overlay',
    }
end

---@param spaces integer
---@param opts? { priority?: integer|false, highlight?: string, combine?: boolean }
---@return vim.api.keyset.set_extmark
function M.padding(spaces, opts)
    opts = opts or {}
    ---@type vim.api.keyset.set_extmark
    return {
        priority = opts.priority or (opts.priority ~= false and 100 or nil),
        hl_mode = opts.combine and 'combine' or nil,
        virt_text = { { (' '):rep(spaces), opts.highlight or 'RmPadding' } },
        virt_text_pos = 'inline',
    }
end

---@class notedown.test.Indent
M.indent = {}

---@param lengths integer[]
---@return vim.api.keyset.set_extmark
function M.indent.inline(lengths)
    ---@type vim.api.keyset.set_extmark
    return {
        priority = 0,
        virt_text = M.indent.line(lengths),
        virt_text_pos = 'inline',
    }
end

---@param opts vim.api.keyset.set_extmark
---@param lengths integer[]
---@return vim.api.keyset.set_extmark
function M.indent.virtual(opts, lengths)
    local line = M.indent.line(lengths)
    vim.list_extend(line, opts.virt_lines[1])
    opts.virt_lines = { line }
    return opts
end

---@private
---@param lengths integer[]
---@return notedown.mark.Line
function M.indent.line(lengths)
    local result = {} ---@type notedown.mark.Line
    for _, length in ipairs(lengths) do
        if length == 1 then
            result[#result + 1] = { '▎', 'RmIndent' }
        else
            result[#result + 1] = { (' '):rep(length), 'RmPadding' }
        end
    end
    return result
end

---@class notedown.test.Heading
M.heading = {}

---@param level integer
---@return vim.api.keyset.set_extmark
function M.heading.sign(level)
    ---@type vim.api.keyset.set_extmark
    return {
        sign_text = '󰫎 ',
        sign_hl_group = ('Rm_RmH%d_RmSign'):format(level),
    }
end

---@param level integer
---@return vim.api.keyset.set_extmark
function M.heading.icon(level)
    local icons =
        { '󰲡 ', ' 󰲣 ', '  󰲥 ', '   󰲧 ', '    󰲩 ', '     󰲫 ' }
    local highlight = ('RmH%d:RmH%dBg'):format(level, level)
    ---@type vim.api.keyset.set_extmark
    return {
        virt_text = { { icons[level], highlight } },
        virt_text_pos = 'overlay',
    }
end

---@param level integer
---@return vim.api.keyset.set_extmark
function M.heading.bg(level)
    ---@type vim.api.keyset.set_extmark
    return {
        hl_eol = true,
        hl_group = ('RmH%dBg'):format(level),
    }
end

---@class notedown.test.Table
M.table = {}

---@param head boolean
---@return vim.api.keyset.set_extmark
function M.table.pipe(head)
    local highlight = head and 'RmTableHead' or 'RmTableRow'
    ---@type vim.api.keyset.set_extmark
    return {
        virt_text = { { '│', highlight } },
        virt_text_pos = 'overlay',
    }
end

---@param virtual boolean
---@param above boolean
---@param ... integer
---@return vim.api.keyset.set_extmark
function M.table.border(virtual, above, ...)
    local chars = above and { '┌', '┬', '┐' } or { '└', '┴', '┘' }
    local highlight = above and 'RmTableHead' or 'RmTableRow'
    local inner = vim.iter({ ... })
        :map(function(length)
            return ('─'):rep(length)
        end)
        :join(chars[2])
    local text = chars[1] .. inner .. chars[3]
    if virtual then
        ---@type vim.api.keyset.set_extmark
        return {
            virt_lines = { { { text, highlight } } },
            virt_lines_above = above,
        }
    else
        ---@type vim.api.keyset.set_extmark
        return {
            virt_text = { { text, highlight } },
            virt_text_pos = 'overlay',
        }
    end
end

---@param padding integer
---@param ... integer[]
---@return vim.api.keyset.set_extmark
function M.table.delimiter(padding, ...)
    local inner = vim.iter({ ... })
        :map(function(widths)
            return vim.iter(widths)
                :map(function(amount)
                    return amount == 1 and '━' or ('─'):rep(amount)
                end)
                :join('')
        end)
        :join('┼')
    local line = { { '├' .. inner .. '┤', 'RmTableHead' } }
    if padding > 0 then
        line[#line + 1] = { (' '):rep(padding), 'RmPadding' }
    end
    ---@type vim.api.keyset.set_extmark
    return {
        virt_text = line,
        virt_text_pos = 'overlay',
    }
end

---@param spaces integer
---@return vim.api.keyset.set_extmark
function M.table.padding(spaces)
    return M.padding(spaces, { priority = 0 })
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

---@param marks notedown.test.Marks
---@param screen string[]
function M.assert_view(marks, screen)
    M.assert_marks(marks:get())
    M.assert_screen(screen)
end

---@param expected notedown.test.MarkInfo[]
function M.assert_marks(expected)
    local actual = M.actual_marks()
    for i = 1, math.min(#expected, #actual) do
        local message = ('marks at index %d mismatch'):format(i)
        assert.same(expected[i], actual[i], message)
    end
    assert.same(#expected, #actual, 'different number of marks found')
end

---@private
---@return notedown.test.MarkInfo[]
function M.actual_marks()
    local ui = require('notedown.core.ui')
    local marks = vim.api.nvim_buf_get_extmarks(0, ui.ns, 0, -1, {
        details = true,
    })
    local actual = {} ---@type notedown.test.MarkDetails[]
    for _, mark in ipairs(marks) do
        local row, col = mark[2], mark[3]
        local details = assert(mark[4], 'missing details')
        local info = require('tests.helpers.details').new(row, col, details)
        actual[#actual + 1] = info
    end
    table.sort(actual)
    return actual
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
        -- Remove tailing whitespace to make tests easier to write
        line = line:gsub('%s+$', '')
        -- Stop collecting lines once we reach an empty one
        if line == '~' then
            break
        end
        actual[#actual + 1] = line
    end
    return actual
end

return M
