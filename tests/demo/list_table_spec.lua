---@module 'luassert'

local util = require('tests.util')

describe('demo/list_table.md', function()

    it('default', function()
        util.setup.file('demo/list_table.md')

        util.assert_screen({
            'Unordered List',
            '',
            '   List Item 1: with link',
            '   List Item 2: with inline code',
            '       Nested List 1 Item 1',
            '       Nested List 1 Item 2',
            '        󰨓 Nested List 2 Item 1',
            '          󰨔 Nested List 3 Item 1',
            '             Nested List 4 Item 1',
            '   List Item 3: with reference link',
            '',
            'Ordered List',
            '',
            '  1. Item 1',
            '  2. Item 2',
            '',
            'Table',
            '┌────────┬───────────────┬───────┬──────┐',
            '│ Left   │    Center     │ Right │ None │',
            '├━───────┼━─────────────━┼──────━┼──────┤',
            '│ Code   │   **Bold**    │ Plain │ Item │',
            '│ Item   │     link      │  Item │ Item │',
            '└────────┴───────────────┴───────┴──────┘',
            '[example]: https://example.com',
        })
    end)

end)
