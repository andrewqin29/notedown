---@module 'luassert'

local util = require('tests.util')

describe('ad hoc', function()
    it('setext', function()
        -- setext headings aren't part of the format: rendered as plain text
        util.setup.text({
            'Heading 2 Line 1',
            'Heading 2 Line 2',
            '---',
        })
        local marks = util.marks()
        util.assert_view(marks, {
            'Heading 2 Line 1',
            'Heading 2 Line 2',
            '---',
        })
    end)

    it('shortcut', function()
        util.setup.text({ '[Normal Shortcut]' })
        local marks = util.marks()
        util.assert_view(marks, { 'Normal Shortcut' })
    end)
end)
