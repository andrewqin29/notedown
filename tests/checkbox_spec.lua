---@module 'luassert'

local util = require('tests.util')

describe('checkbox', function()
    it('handle nested list items', function()
        util.setup.text({
            '1.  -  [x]  Checked Checkbox',
            '1.  -  [ ]  Unchecked Checkbox',
        })
        util.assert_screen({
            '1.    󰱒   Checked Checkbox',
            '2.    󰄱   Unchecked Checkbox',
        })
    end)

    it('ignores invalid position', function()
        util.setup.text({
            '- Todo [-] Checkbox',
        })
        util.assert_screen({
            '   Todo - Checkbox',
        })
    end)

    it('handles character splitting', function()
        util.setup.text({
            '- [ ] Unchecked Checkbox',
        }, {
            checkbox = { unchecked = { icon = 'é' } },
        })
        util.assert_screen({
            '  é Unchecked Checkbox',
        })
    end)
end)
