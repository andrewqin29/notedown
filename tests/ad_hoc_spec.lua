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
        util.assert_screen({
            'Heading 2 Line 1',
            'Heading 2 Line 2',
            '---',
        })
    end)

    it('shortcut', function()
        util.setup.text({ '[Normal Shortcut]' })
        util.assert_screen({ 'Normal Shortcut' })
    end)
end)
