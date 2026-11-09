---notedown's look: the icons, colors and spacing each part of a note is drawn
---with. These are the defaults `require('notedown').setup(opts)` merges opts
---into. Highlight groups named Notedown* are defined in core/colors.lua.
---@class notedown.Settings
local M = {}

---@alias notedown.Modes boolean|string[]

---What every part has: whether it's drawn, and in which modes besides the
---top-level render_modes.
---@class (exact) notedown.base.Config
---@field enabled boolean
---@field render_modes notedown.Modes

---Parts of the rendering, for anti-conceal.
---@enum notedown.Element
M.element = {
    bullet = 'bullet',
    check_icon = 'check_icon',
    dash = 'dash',
    head_background = 'head_background',
    head_icon = 'head_icon',
    quote = 'quote',
    table_border = 'table_border',
    virtual_lines = 'virtual_lines',
}

---@alias notedown.conceal.Ignore table<notedown.Element, notedown.Modes>

---The line under the cursor shows as typed.
---@class (exact) notedown.anti.conceal.Config
---@field enabled boolean
---@field ignore notedown.conceal.Ignore parts that stay drawn on that line
M.anti_conceal = {
    enabled = true,
    ignore = { virtual_lines = true },
}

---@class (exact) notedown.bullet.Config: notedown.base.Config
---@field icons string[] by nesting level, cycling
---@field left_pad integer columns a list is moved in from the text around it
---@field highlight string
M.bullet = {
    enabled = true,
    render_modes = false,
    -- medium dots (Nerd Font octicons dot-fill and dot), then medium squares
    -- (Nerd Font Material Design icons), each one column wide
    icons = { '\u{f444}', '\u{f4c3}', '\u{f0a13}', '\u{f0a14}' },
    left_pad = 2,
    highlight = 'NotedownBullet',
}

---@class (exact) notedown.checkbox.component.Config
---@field icon string
---@field highlight string

---@class (exact) notedown.checkbox.Config: notedown.base.Config
---@field left_pad integer
---@field right_pad integer
---@field unchecked notedown.checkbox.component.Config
---@field checked notedown.checkbox.component.Config
M.checkbox = {
    enabled = true,
    render_modes = false,
    left_pad = 2,
    right_pad = 1,
    unchecked = { icon = '󰄱 ', highlight = 'NotedownUnchecked' },
    checked = { icon = '󰱒 ', highlight = 'NotedownChecked' },
}

---Thematic breaks (---).
---@class (exact) notedown.dash.Config: notedown.base.Config
---@field icon string
---@field highlight string
M.dash = {
    enabled = true,
    render_modes = false,
    icon = '─',
    highlight = 'NotedownDash',
}

---@class (exact) notedown.heading.Config: notedown.base.Config
---@field backgrounds table<integer, string> bar across the window, by level
M.heading = {
    enabled = true,
    render_modes = false,
    -- none for # and ##, which are images (notes/heading_images.lua)
    backgrounds = {
        [3] = 'NotedownH3Bg',
        [4] = 'NotedownH4Bg',
        [5] = 'NotedownH5Bg',
        [6] = 'NotedownH6Bg',
    },
}

---@class (exact) notedown.inline.highlight.Config: notedown.base.Config
---@field highlight string
M.inline_highlight = {
    enabled = true,
    render_modes = false,
    -- bright yellow (notes/blocks.lua, define_highlights)
    highlight = 'NotesHighlight',
}

---Whitespace added in rendering.
---@class (exact) notedown.padding.Config
---@field highlight string
M.padding = {
    highlight = 'NotedownPadding',
}

---@class (exact) notedown.table.Config: notedown.base.Config
---@field wrap boolean fit wide tables to the window by wrapping cells
---@field padding integer space between cell text and border
---@field border string[] top(3), delimiter(3), bottom(3), vertical, horizontal
---@field alignment_indicator string in the delimiter row, by alignment
---@field head string highlight of the heading, delimiter and line above
---@field row string highlight of the rows and line below
M.pipe_table = {
    enabled = true,
    render_modes = false,
    wrap = true,
    padding = 1,
    -- stylua: ignore
    border = {
        '┌', '┬', '┐',
        '├', '┼', '┤',
        '└', '┴', '┘',
        '│', '─',
    },
    alignment_indicator = '━',
    head = 'NotedownTableHead',
    row = 'NotedownTableRow',
}

---@class (exact) notedown.quote.Config: notedown.base.Config
---@field icon string replaces each >
---@field highlight string[] by nesting level, cycling
M.quote = {
    enabled = true,
    render_modes = false,
    icon = '▋',
    highlight = {
        'NotedownQuote1',
        'NotedownQuote2',
        'NotedownQuote3',
        'NotedownQuote4',
        'NotedownQuote5',
        'NotedownQuote6',
    },
}

---@alias notedown.option.Value number|integer|string|boolean

---Window options while rendered, and the user's own to go back to.
---@class (exact) notedown.window.Config
---@field default notedown.option.Value
---@field rendered notedown.option.Value

---@alias notedown.window.Configs table<string, notedown.window.Config>

---@type notedown.window.Configs
M.win_options = {
    -- concealed text completely hidden
    conceallevel = { default = vim.o.conceallevel, rendered = 3 },
    -- and on the cursor line too, where anti-conceal shows the source instead
    concealcursor = { default = vim.o.concealcursor, rendered = '' },
    -- wrap between words, not mid-word
    linebreak = { default = vim.o.linebreak, rendered = true },
    -- a wrapped list item or quote continues under its text; how far in comes
    -- from 'formatlistpat' (notes/blocks.lua, list_pattern)
    breakindent = { default = vim.o.breakindent, rendered = true },
    breakindentopt = { default = vim.o.breakindentopt, rendered = 'list:-1' },
}

return M
