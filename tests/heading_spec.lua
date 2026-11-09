---@module 'luassert'

local util = require('tests.util')

describe('heading', function()
    local lines = {
        '',
        '# Head 1',
        '',
        '## Head 2',
        '### H3',
        '#### H4',
        '',
        '  ##### Head 5',
        '',
        '###### Head 6',
        '',
        'Ext Heading',
        '===',
        '',
        'Ext Heading 2',
        'Ext Heading 2 Line 2',
        '---',
        '',
        '> # Nested Heading',
    }

    it('default', function()
        util.setup.text(lines)
        util.assert_screen({
            '',
            'Head 1',
            '',
            'Head 2',
            'H3',
            'H4',
            '',
            'Head 5',
            '',
            'Head 6',
            '',
            'Ext Heading',
            '===',
            '',
            'Ext Heading 2',
            'Ext Heading 2 Line 2',
            '---',
            '',
            '▋ Nested Heading',
        })
    end)

end)
