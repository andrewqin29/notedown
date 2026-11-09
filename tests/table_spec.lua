---@module 'luassert'

local util = require('tests.util')

describe('table', function()
    local lines = {
        '',
        '| Heading 1 | `Heading 2`            |',
        '| --------- | ---------------------: |',
        '| `Item 行` | [link](https://行.com) |',
        '| &lt;1&gt; | ==Itém 2==             |',
        '| Regular   | [[行\\|link]]           |',
        '',
        '| Heading 1 | Heading 2 |',
        '| --------- | --------- |',
        '| Item 1    | Item 2    |',
    }

    it('default', function()
        util.setup.text(lines)

        util.assert_screen({
            '┌───────────┬────────────────────────┐',
            '│ Heading 1 │              Heading 2 │',
            '├───────────┼───────────────────────━┤',
            '│ Item 行   │                   link │',
            '│ 1         │                 Itém 2 │',
            '│ Regular   │              [行|link] │',
            '└───────────┴────────────────────────┘',
            '┌───────────┬───────────┐',
            '│ Heading 1 │ Heading 2 │',
            '├───────────┼───────────┤',
            '│ Item 1    │ Item 2    │',
            '└───────────┴───────────┘',
        })
    end)

end)
