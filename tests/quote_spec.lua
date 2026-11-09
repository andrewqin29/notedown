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

        local marks, row = util.marks(), util.row()

        local levels = {
            'RmQuote1',
            'RmQuote2',
            'RmQuote3',
            'RmQuote3',
        }

        marks:add(row:get(0, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))

        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))
        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))

        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))
        marks:add(row:get(0, 0), { 4, 5 }, util.quote(levels[3]))
        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))
        marks:add(row:get(0, 0), { 4, 5 }, util.quote(levels[3]))
        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))
        marks:add(row:get(0, 0), { 4, 5 }, util.quote(levels[3]))

        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))

        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))
        marks:add(row:get(0, 0), { 4, 5 }, util.quote(levels[4]))

        util.assert_view(marks, {
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

        local marks, row = util.marks(), util.row()

        local levels = {
            'RmQuote1',
            'RmQuote2',
        }

        marks:add(row:get(0, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.heading.icon(1))
        marks:add(row:get(0, 1), { 2, 0 }, util.heading.bg(1))
        marks:add(row:get(0, 0), { 0, 1 }, util.quote(levels[1]))

        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))
        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))
        marks:add(row:get(1, 0), { 0, 1 }, util.quote(levels[1]))
        marks:add(row:get(0, 0), { 2, 3 }, util.quote(levels[2]))

        util.assert_view(marks, {
            '▋ 󰲡 Heading',
            '▋',
            '▋ ▋ Tip',
            '▋ ▋',
            '▋ ▋ Text',
        })
    end)
end)
