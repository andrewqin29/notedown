---@module 'luassert'

local util = require('tests.util')

describe('quote', function()
    it('nested', function()
        util.setup.text({
            '> Important',
            '>',
            '> Important',
            '>',
            '> > Normal',
            '> > Note',
            '> > > Caution',
            '> > > Lookout',
            '> > >',
            '> Important',
            '> > > New',
        })

        util.assert_screen({
            '▋ Important',
            '▋',
            '▋ Important',
            '▋',
            '▋ ▋ Normal',
            '▋ ▋ Note',
            '▋ ▋ ▋ Caution',
            '▋ ▋ ▋ Lookout',
            '▋ ▋ ▋',
            '▋ Important',
            '▋ ▋ ▋ New',
        })
    end)

    it('heading', function()
        util.setup.text({
            '> # Heading',
            '>',
            '> > Tip',
            '> >',
            '> > Text',
        })

        util.assert_screen({
            '▋ Heading',
            '▋',
            '▋ ▋ Tip',
            '▋ ▋',
            '▋ ▋ Text',
        })
    end)
end)
