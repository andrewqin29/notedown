---@module 'luassert'

local util = require('tests.util')

describe('demo/box_dash_quote.md', function()
    it('default', function()
        util.setup.file('demo/box_dash_quote.md')

        util.assert_screen({
            'Checkbox / Dash / Quote',
            '',
            '  󰄱  Unchecked Checkbox',
            '  󰱒  Checked Checkbox',
            '   Regular List Item',
            '',
            '────────────────────────────────────────────────────────────────────────────────',
            '',
            '  ▋ Quote line 1',
            '  ▋ Quote line 2',
        })
    end)
end)
