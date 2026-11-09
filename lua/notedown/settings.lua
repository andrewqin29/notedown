---@class notedown.Settings
local M = {}

---@class notedown.anti.conceal.Settings
M.anti_conceal = {}

---@class (exact) notedown.anti.conceal.Config
---@field enabled boolean
---@field disabled_modes notedown.Modes
---@field above integer
---@field below integer
---@field ignore notedown.conceal.Ignore

---@alias notedown.conceal.Ignore table<notedown.Element, notedown.Modes>

---@enum notedown.Element
M.anti_conceal.element = {
    bullet = 'bullet',
    check_icon = 'check_icon',
    check_scope = 'check_scope',
    dash = 'dash',
    head_background = 'head_background',
    head_border = 'head_border',
    head_icon = 'head_icon',
    quote = 'quote',
    table_border = 'table_border',
    virtual_lines = 'virtual_lines',
}

---@type notedown.anti.conceal.Config
M.anti_conceal.default = {
    -- This enables hiding added text on the line the cursor is on.
    enabled = true,
    -- Modes to disable anti conceal feature.
    disabled_modes = false,
    -- Number of lines above cursor to show.
    above = 0,
    -- Number of lines below cursor to show.
    below = 0,
    -- Which elements to always show, ignoring anti conceal behavior. Values can either be
    -- booleans to fix the behavior or string lists representing modes where anti conceal
    -- behavior will be ignored. Valid values are:
    --   bullet
    --   check_icon, check_scope
    --   dash
    --   head_background, head_border, head_icon
    --   quote
    --   table_border
    --   virtual_lines
    ignore = {
        virtual_lines = true,
    },
}

---@return notedown.Schema
function M.anti_conceal.schema()
    ---@type notedown.Schema
    local modes = {
        union = { { list = { type = 'string' } }, { type = 'boolean' } },
    }
    ---@type notedown.Schema
    return {
        record = {
            enabled = { type = 'boolean' },
            disabled_modes = modes,
            above = { type = 'number' },
            below = { type = 'number' },
            ignore = { map = { { enum = M.anti_conceal.element }, modes } },
        },
    }
end

---@class notedown.base.Settings
M.base = {}

---@class (exact) notedown.base.Config
---@field enabled boolean
---@field render_modes notedown.Modes

---@alias notedown.Modes boolean|string[]

---@param child notedown.schema.Record
---@return notedown.Schema
function M.base.schema(child)
    ---@type notedown.schema.Record
    local parent = {
        enabled = { type = 'boolean' },
        render_modes = {
            union = { { list = { type = 'string' } }, { type = 'boolean' } },
        },
    }
    ---@type notedown.Schema
    return { record = vim.tbl_deep_extend('error', parent, child) }
end

---@class notedown.bullet.Settings
M.bullet = {}

---@class (exact) notedown.bullet.Config: notedown.base.Config
---@field icons notedown.bullet.String
---@field ordered_icons notedown.bullet.String
---@field left_pad notedown.bullet.Integer
---@field right_pad notedown.bullet.Integer
---@field highlight notedown.bullet.String
---@field scope_highlight notedown.bullet.String
---@field scope_priority? integer

---@class (exact) notedown.bullet.Context
---@field level integer
---@field index integer
---@field value string

---@alias notedown.bullet.String
---| string
---| string[]
---| string[][]
---| fun(ctx: notedown.bullet.Context): string?

---@alias notedown.bullet.Integer
---| integer
---| fun(ctx: notedown.bullet.Context): integer

---@type notedown.bullet.Config
M.bullet.default = {
    -- Useful context to have when evaluating values.
    -- | level | how deeply nested the list is, 1-indexed          |
    -- | index | how far down the item is at that level, 1-indexed |
    -- | value | text value of the marker node                     |

    -- Turn on / off list bullet rendering
    enabled = true,
    -- Additional modes to render list bullets
    render_modes = false,
    -- Replaces '-'|'+'|'*' of 'list_item'.
    -- If the item is a 'checkbox' a conceal is used to hide the bullet instead.
    -- Output is evaluated depending on the type.
    -- | function   | `value(context)`                                    |
    -- | string     | `value`                                             |
    -- | string[]   | `cycle(value, context.level)`                       |
    -- | string[][] | `clamp(cycle(value, context.level), context.index)` |
    icons = { '●', '○', '◆', '◇' },
    -- Replaces 'n.'|'n)' of 'list_item'.
    -- Output is evaluated using the same logic as 'icons'.
    ordered_icons = function(ctx)
        local value = vim.trim(ctx.value)
        local index = tonumber(value:sub(1, #value - 1)) or 0
        return ('%d.'):format(index > 1 and index or ctx.index)
    end,
    -- Padding to add to the left of bullet point.
    -- Output is evaluated depending on the type.
    -- | function | `value(context)` |
    -- | integer  | `value`          |
    left_pad = 0,
    -- Padding to add to the right of bullet point.
    -- Output is evaluated using the same logic as 'left_pad'.
    right_pad = 0,
    -- Highlight for the bullet icon.
    -- Output is evaluated using the same logic as 'icons'.
    highlight = 'NotedownBullet',
    -- Highlight for item associated with the bullet point.
    -- Output is evaluated using the same logic as 'icons'.
    scope_highlight = {},
    -- Priority to assign to scope highlight.
    scope_priority = nil,
}

---@return notedown.Schema
function M.bullet.schema()
    ---@type notedown.Schema
    local string_provider = {
        union = {
            { type = 'string' },
            { list = { type = 'string' } },
            { list = { list = { type = 'string' } } },
            { type = 'function' },
        },
    }
    ---@type notedown.Schema
    local integer_provider = {
        union = { { type = 'number' }, { type = 'function' } },
    }
    return M.base.schema({
        icons = string_provider,
        ordered_icons = string_provider,
        left_pad = integer_provider,
        right_pad = integer_provider,
        highlight = string_provider,
        scope_highlight = string_provider,
        scope_priority = { optional = true, type = 'number' },
    })
end

---@class notedown.checkbox.Settings
M.checkbox = {}

---@class (exact) notedown.checkbox.Config: notedown.base.Config
---@field bullet boolean
---@field left_pad number
---@field right_pad integer
---@field unchecked notedown.checkbox.component.Config
---@field checked notedown.checkbox.component.Config
---@field scope_priority? integer

---@class (exact) notedown.checkbox.component.Config
---@field icon string
---@field highlight string
---@field scope_highlight? string

---@type notedown.checkbox.Config
M.checkbox.default = {
    -- Checkboxes: '[ ]' and '[x]' at the start of a list item.

    -- Turn on / off checkbox state rendering.
    enabled = true,
    -- Additional modes to render checkboxes.
    render_modes = false,
    -- Render the bullet point before the checkbox.
    bullet = false,
    -- Padding to add to the left of checkboxes.
    left_pad = 0,
    -- Padding to add to the right of checkboxes.
    right_pad = 1,
    unchecked = {
        -- Replaces '[ ]' of 'task_list_marker_unchecked'.
        icon = '󰄱 ',
        -- Highlight for the unchecked icon.
        highlight = 'NotedownUnchecked',
        -- Highlight for item associated with unchecked checkbox.
        scope_highlight = nil,
    },
    checked = {
        -- Replaces '[x]' of 'task_list_marker_checked'.
        icon = '󰱒 ',
        -- Highlight for the checked icon.
        highlight = 'NotedownChecked',
        -- Highlight for item associated with checked checkbox.
        scope_highlight = nil,
    },
    -- Priority to assign to scope highlight.
    scope_priority = nil,
}

---@return notedown.Schema
function M.checkbox.schema()
    ---@type notedown.Schema
    local component = {
        record = {
            icon = { type = 'string' },
            highlight = { type = 'string' },
            scope_highlight = { optional = true, type = 'string' },
        },
    }
    return M.base.schema({
        bullet = { type = 'boolean' },
        left_pad = { type = 'number' },
        right_pad = { type = 'number' },
        unchecked = component,
        checked = component,
        scope_priority = { optional = true, type = 'number' },
    })
end

---@class notedown.dash.Settings
M.dash = {}

---@class (exact) notedown.dash.Config: notedown.base.Config
---@field icon string
---@field width notedown.dash.Width
---@field left_margin number
---@field priority? integer
---@field highlight string

---@class (exact) notedown.dash.Context
---@field width integer

---@alias notedown.dash.Width
---| 'full'
---| number
---| fun(ctx: notedown.dash.Context): integer

---@type notedown.dash.Config
M.dash.default = {
    -- Useful context to have when evaluating values.
    -- | width | width of the current window |

    -- Turn on / off thematic break rendering.
    enabled = true,
    -- Additional modes to render dash.
    render_modes = false,
    -- Replaces '---'|'***'|'___'|'* * *' of 'thematic_break'.
    -- The icon gets repeated across the window's width.
    icon = '─',
    -- Width of the generated line.
    -- If a float < 1 is provided it is treated as a percentage of available window space.
    -- Output is evaluated depending on the type.
    -- | function | `value(context)`    |
    -- | number   | `value`             |
    -- | full     | width of the window |
    width = 'full',
    -- Amount of margin to add to the left of dash.
    -- If a float < 1 is provided it is treated as a percentage of available window space.
    left_margin = 0,
    -- Priority to assign to dash.
    priority = nil,
    -- Highlight for the whole line generated from the icon.
    highlight = 'NotedownDash',
}

---@return notedown.Schema
function M.dash.schema()
    return M.base.schema({
        icon = { type = 'string' },
        width = {
            union = {
                { enum = { 'full' } },
                { type = 'number' },
                { type = 'function' },
            },
        },
        left_margin = { type = 'number' },
        priority = { optional = true, type = 'number' },
        highlight = { type = 'string' },
    })
end

---@class notedown.document.Settings
M.document = {}

---@class (exact) notedown.document.Config: notedown.base.Config
---@field conceal notedown.document.conceal.Config

---@class (exact) notedown.document.conceal.Config
---@field char_patterns string[]
---@field line_patterns string[]

---@type notedown.document.Config
M.document.default = {
    -- Turn on / off document rendering.
    enabled = true,
    -- Additional modes to render document.
    render_modes = false,
    -- Ability to conceal arbitrary ranges of text based on lua patterns, @see :h lua-patterns.
    -- Relies entirely on user to set patterns that handle their edge cases.
    conceal = {
        -- Matched ranges will be concealed using character level conceal.
        char_patterns = {},
        -- Matched ranges will be concealed using line level conceal.
        line_patterns = {},
    },
}

---@return notedown.Schema
function M.document.schema()
    return M.base.schema({
        conceal = {
            record = {
                char_patterns = { list = { type = 'string' } },
                line_patterns = { list = { type = 'string' } },
            },
        },
    })
end

---@class notedown.heading.Settings
M.heading = {}

---@class (exact) notedown.heading.Config: notedown.base.Config
---@field atx boolean
---@field icons notedown.heading.String
---@field position notedown.heading.Position
---@field width notedown.heading.Width|(notedown.heading.Width)[]
---@field left_margin number|number[]
---@field left_pad number|number[]
---@field right_pad number|number[]
---@field min_width integer|integer[]
---@field border boolean|boolean[]
---@field border_virtual boolean
---@field border_prefix boolean
---@field above string
---@field below string
---@field backgrounds string[]
---@field foregrounds string[]
---@field custom table<string, notedown.heading.Custom>

---@class (exact) notedown.heading.Context
---@field level integer
---@field sections integer[]

---@alias notedown.heading.String
---| string[]
---| fun(ctx: notedown.heading.Context): string?

---@enum notedown.heading.Position
M.heading.position = {
    overlay = 'overlay',
    inline = 'inline',
    right = 'right',
    eol = 'eol',
}

---@enum notedown.heading.Width
M.heading.width = {
    full = 'full',
    block = 'block',
}

---@class (exact) notedown.heading.Custom
---@field pattern string
---@field icon? string
---@field background? string
---@field foreground? string

---@type notedown.heading.Config
M.heading.default = {
    -- Useful context to have when evaluating values.
    -- | level    | the number of '#' in the heading marker         |
    -- | sections | for each level how deeply nested the heading is |

    -- Turn on / off heading icon & background rendering.
    enabled = true,
    -- Additional modes to render headings.
    render_modes = false,
    -- Turn on / off atx heading rendering.
    atx = true,
    -- Replaces '#+' of 'atx_h._marker'.
    -- Output is evaluated depending on the type.
    -- | function | `value(context)`              |
    -- | string[] | `cycle(value, context.level)` |
    icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
    -- Determines how icons fill the available space.
    -- | eol     | '#'s are concealed and icon is placed at right most column   |
    -- | right   | '#'s are concealed and icon is appended to right side        |
    -- | inline  | '#'s are concealed and icon is inlined on left side          |
    -- | overlay | icon is left padded with spaces and overlayed hiding all '#' |
    position = 'overlay',
    -- Width of the heading background.
    -- | block | width of the heading text |
    -- | full  | full width of the window  |
    -- Can also be a list of the above values evaluated by `clamp(value, context.level)`.
    width = 'full',
    -- Amount of margin to add to the left of headings.
    -- Margin available space is computed after accounting for padding.
    -- If a float < 1 is provided it is treated as a percentage of available window space.
    -- Can also be a list of numbers evaluated by `clamp(value, context.level)`.
    left_margin = 0,
    -- Amount of padding to add to the left of headings.
    -- Output is evaluated using the same logic as 'left_margin'.
    left_pad = 0,
    -- Amount of padding to add to the right of headings when width is 'block'.
    -- Output is evaluated using the same logic as 'left_margin'.
    right_pad = 0,
    -- Minimum width to use for headings when width is 'block'.
    -- Can also be a list of integers evaluated by `clamp(value, context.level)`.
    min_width = 0,
    -- Determines if a border is added above and below headings.
    -- Can also be a list of booleans evaluated by `clamp(value, context.level)`.
    border = false,
    -- Always use virtual lines for heading borders instead of attempting to use empty lines.
    border_virtual = false,
    -- Highlight the start of the border using the foreground highlight.
    border_prefix = false,
    -- Used above heading for border.
    above = '▄',
    -- Used below heading for border.
    below = '▀',
    -- Highlight for the heading icon and extends through the entire line.
    -- Output is evaluated by `clamp(value, context.level)`.
    backgrounds = {
        'NotedownH1Bg',
        'NotedownH2Bg',
        'NotedownH3Bg',
        'NotedownH4Bg',
        'NotedownH5Bg',
        'NotedownH6Bg',
    },
    -- Highlight for the heading and sign icons.
    -- Output is evaluated using the same logic as 'backgrounds'.
    foregrounds = {
        'NotedownH1',
        'NotedownH2',
        'NotedownH3',
        'NotedownH4',
        'NotedownH5',
        'NotedownH6',
    },
    -- Define custom heading patterns which allow you to override various properties based on
    -- the contents of a heading.
    -- The key is for healthcheck and to allow users to change its values, value type below.
    -- | pattern    | matched against the heading text @see :h lua-patterns |
    -- | icon       | optional override for the icon                        |
    -- | background | optional override for the background                  |
    -- | foreground | optional override for the foreground                  |
    custom = {},
}

---@return notedown.Schema
function M.heading.schema()
    ---@type notedown.Schema
    local width = { enum = M.heading.width }
    ---@type notedown.Schema
    local custom = {
        record = {
            pattern = { type = 'string' },
            icon = { optional = true, type = 'string' },
            background = { optional = true, type = 'string' },
            foreground = { optional = true, type = 'string' },
        },
    }
    return M.base.schema({
        atx = { type = 'boolean' },
        icons = {
            union = { { list = { type = 'string' } }, { type = 'function' } },
        },
        position = { enum = M.heading.position },
        width = {
            union = { { list = width }, width },
        },
        left_margin = {
            union = { { list = { type = 'number' } }, { type = 'number' } },
        },
        left_pad = {
            union = { { list = { type = 'number' } }, { type = 'number' } },
        },
        right_pad = {
            union = { { list = { type = 'number' } }, { type = 'number' } },
        },
        min_width = {
            union = { { list = { type = 'number' } }, { type = 'number' } },
        },
        border = {
            union = { { list = { type = 'boolean' } }, { type = 'boolean' } },
        },
        border_virtual = { type = 'boolean' },
        border_prefix = { type = 'boolean' },
        above = { type = 'string' },
        below = { type = 'string' },
        backgrounds = { list = { type = 'string' } },
        foregrounds = { list = { type = 'string' } },
        custom = { map = { { type = 'string' }, custom } },
    })
end

---@class notedown.padding.Settings
M.padding = {}

---@class (exact) notedown.padding.Config
---@field highlight string

---@type notedown.padding.Config
M.padding.default = {
    -- Highlight to use when adding whitespace, should blend in with background.
    highlight = 'NotedownPadding',
}

---@return notedown.Schema
function M.padding.schema()
    ---@type notedown.Schema
    return { record = { highlight = { type = 'string' } } }
end

---@class notedown.paragraph.Settings
M.paragraph = {}

---@class (exact) notedown.paragraph.Config: notedown.base.Config
---@field left_margin notedown.paragraph.Number
---@field indent notedown.paragraph.Number
---@field min_width integer

---@class (exact) notedown.paragraph.Context
---@field text string

---@alias notedown.paragraph.Number
---| number
---| fun(ctx: notedown.paragraph.Context): number

---@type notedown.paragraph.Config
M.paragraph.default = {
    -- Useful context to have when evaluating values.
    -- | text | text value of the node |

    -- Turn on / off paragraph rendering.
    enabled = true,
    -- Additional modes to render paragraphs.
    render_modes = false,
    -- Amount of margin to add to the left of paragraphs.
    -- If a float < 1 is provided it is treated as a percentage of available window space.
    -- Output is evaluated depending on the type.
    -- | function | `value(context)` |
    -- | number   | `value`          |
    left_margin = 0,
    -- Amount of padding to add to the first line of each paragraph.
    -- Output is evaluated using the same logic as 'left_margin'.
    indent = 0,
    -- Minimum width to use for paragraphs.
    min_width = 0,
}

---@return notedown.Schema
function M.paragraph.schema()
    return M.base.schema({
        left_margin = { union = { { type = 'number' }, { type = 'function' } } },
        indent = { union = { { type = 'number' }, { type = 'function' } } },
        min_width = { type = 'number' },
    })
end

---@class notedown.quote.Settings
M.quote = {}

---@class (exact) notedown.quote.Config: notedown.base.Config
---@field icon string|string[]
---@field repeat_linebreak boolean
---@field highlight string|string[]

---@type notedown.quote.Config
M.quote.default = {
    -- Turn on / off block quote rendering.
    enabled = true,
    -- Additional modes to render quotes.
    render_modes = false,
    -- Replaces '>' of 'block_quote'.
    icon = '▋',
    -- Whether to repeat icon on wrapped lines. Requires neovim >= 0.10. This will obscure text
    -- if incorrectly configured with :h 'showbreak', :h 'breakindent' and :h 'breakindentopt'.
    -- A combination of these that is likely to work follows.
    -- | showbreak      | '  ' (2 spaces)   |
    -- | breakindent    | true              |
    -- | breakindentopt | '' (empty string) |
    -- These are not validated by this plugin. If you want to avoid adding these to your main
    -- configuration then set them in win_options for this plugin.
    repeat_linebreak = false,
    -- Highlight for the quote icon.
    -- If a list is provided output is evaluated by `cycle(value, level)`.
    highlight = {
        'NotedownQuote1',
        'NotedownQuote2',
        'NotedownQuote3',
        'NotedownQuote4',
        'NotedownQuote5',
        'NotedownQuote6',
    },
}

---@return notedown.Schema
function M.quote.schema()
    return M.base.schema({
        icon = {
            union = { { list = { type = 'string' } }, { type = 'string' } },
        },
        repeat_linebreak = { type = 'boolean' },
        highlight = {
            union = { { list = { type = 'string' } }, { type = 'string' } },
        },
    })
end

---@class notedown.render.Settings
M.render = {}

---@class (exact) notedown.render.Config
---@field diff boolean

---@type notedown.render.Config
M.render.default = {
    -- Whether to render when window is in diff-mode.
    diff = false,
}

---@return notedown.Schema
function M.render.schema()
    ---@type notedown.Schema
    return {
        record = {
            diff = { type = 'boolean' },
        },
    }
end

---@class notedown.inline.highlight.Settings
M.inline_highlight = {}

---@class (exact) notedown.inline.highlight.Config: notedown.base.Config
---@field highlight string
---@field custom table<string, notedown.inline.highlight.custom.Config>

---@class (exact) notedown.inline.highlight.custom.Config
---@field prefix string
---@field highlight string

---@type notedown.inline.highlight.Config
M.inline_highlight.default = {
    -- Mimics Obsidian inline highlights when content is surrounded by double equals.
    -- The equals on both ends are concealed and the inner content is highlighted.

    -- Turn on / off inline highlight rendering.
    enabled = true,
    -- Additional modes to render inline highlights.
    render_modes = false,
    -- Applies to background of surrounded text.
    highlight = 'NotedownInlineHighlight',
    -- Define custom highlights based on text prefix.
    -- The key is for healthcheck and to allow users to change its values, value type below.
    -- | prefix    | matched against text body, @see :h vim.startswith() |
    -- | highlight | highlight for text body                             |
    custom = {},
}

---@return notedown.Schema
function M.inline_highlight.schema()
    ---@type notedown.Schema
    local custom = {
        record = {
            prefix = { type = 'string' },
            highlight = { type = 'string' },
        },
    }
    return M.base.schema({
        highlight = { type = 'string' },
        custom = { map = { { type = 'string' }, custom } },
    })
end

---@class notedown.pipe.table.Settings
M.pipe_table = {}

---@class (exact) notedown.table.Config: notedown.base.Config
---@field preset notedown.table.Preset
---@field cell notedown.table.Cell
---@field wrap boolean
---@field grid boolean
---@field cell_offset fun(ctx: notedown.table.cell.Context): integer
---@field padding integer
---@field min_width integer
---@field border string[]
---@field border_enabled boolean
---@field border_priority? integer
---@field border_virtual boolean
---@field alignment_indicator string
---@field head string
---@field row string
---@field style notedown.table.Style

---@class (exact) notedown.table.cell.Context
---@field node TSNode

---@enum notedown.table.Preset
M.pipe_table.preset = {
    none = 'none',
    round = 'round',
    double = 'double',
    heavy = 'heavy',
}

---@enum notedown.table.Cell
M.pipe_table.cell = {
    trimmed = 'trimmed',
    padded = 'padded',
    raw = 'raw',
    overlay = 'overlay',
}

---@enum notedown.table.Style
M.pipe_table.style = {
    full = 'full',
    normal = 'normal',
    none = 'none',
}

---@type notedown.table.Config
M.pipe_table.default = {
    -- Turn on / off pipe table rendering.
    enabled = true,
    -- Additional modes to render pipe tables.
    render_modes = false,
    -- Pre configured settings largely for setting table border easier.
    -- | heavy  | use thicker border characters     |
    -- | double | use double line border characters |
    -- | round  | use round border corners          |
    -- | none   | does nothing                      |
    preset = 'none',
    -- Determines how individual cells of a table are rendered.
    -- | overlay | writes completely over the table, removing conceal behavior and highlights |
    -- | raw     | replaces only the '|' characters in each row, leaving the cells unmodified |
    -- | padded  | raw + cells are padded to maximum visual width for each column             |
    -- | trimmed | padded except empty space is subtracted from visual width calculation      |
    cell = 'padded',
    -- Fit wide tables to the current window by wrapping individual cells.
    wrap = true,
    -- Draw a horizontal line between every body row.
    grid = false,
    -- Adjust the computed width of table cells using custom logic.
    cell_offset = function()
        return 0
    end,
    -- Amount of space to put between cell contents and border.
    padding = 1,
    -- Minimum column width to use for padded or trimmed cell.
    min_width = 0,
    -- Characters used to replace table border.
    -- Correspond to top(3), delimiter(3), bottom(3), vertical, & horizontal.
    -- stylua: ignore
    border = {
        '┌', '┬', '┐',
        '├', '┼', '┤',
        '└', '┴', '┘',
        '│', '─',
    },
    -- Turn on / off top & bottom lines.
    border_enabled = true,
    -- Priority to assign to table border.
    border_priority = nil,
    -- Always use virtual lines for table borders instead of attempting to use empty lines.
    -- Will be automatically enabled if indentation module is enabled.
    border_virtual = false,
    -- Gets placed in delimiter row for each column, position is based on alignment.
    alignment_indicator = '━',
    -- Highlight for table heading, delimiter, and the line above.
    head = 'NotedownTableHead',
    -- Highlight for everything else, main table rows and the line below.
    row = 'NotedownTableRow',
    -- Determines how the table as a whole is rendered.
    -- | none   | { enabled = false }        |
    -- | normal | { border_enabled = false } |
    -- | full   | uses all default values    |
    style = 'full',
}

---@return notedown.Schema
function M.pipe_table.schema()
    return M.base.schema({
        preset = { enum = M.pipe_table.preset },
        cell = { enum = M.pipe_table.cell },
        wrap = { type = 'boolean' },
        grid = { type = 'boolean' },
        cell_offset = { type = 'function' },
        padding = { type = 'number' },
        min_width = { type = 'number' },
        border = { list = { type = 'string' } },
        border_enabled = { type = 'boolean' },
        border_priority = { optional = true, type = 'number' },
        border_virtual = { type = 'boolean' },
        alignment_indicator = { type = 'string' },
        head = { type = 'string' },
        row = { type = 'string' },
        style = { enum = M.pipe_table.style },
    })
end

---@class notedown.win.options.Settings
M.win_options = {}

---@alias notedown.window.Configs table<string, notedown.window.Config>

---@class (exact) notedown.window.Config
---@field default notedown.option.Value
---@field rendered notedown.option.Value

---@alias notedown.option.Value number|integer|string|boolean

---@type notedown.window.Configs
M.win_options.default = {
    -- Window options to use that change between rendered and raw view.

    -- @see :h 'conceallevel'
    conceallevel = {
        -- Used when not being rendered, get user setting.
        default = vim.o.conceallevel,
        -- Used when being rendered, concealed text is completely hidden.
        rendered = 3,
    },
    -- @see :h 'concealcursor'
    concealcursor = {
        -- Used when not being rendered, get user setting.
        default = vim.o.concealcursor,
        -- Used when being rendered, show concealed text in all modes.
        rendered = '',
    },
}

---@return notedown.Schema
function M.win_options.schema()
    ---@type notedown.Schema
    local value = {
        union = {
            { type = 'number' },
            { type = 'string' },
            { type = 'boolean' },
        },
    }
    ---@type notedown.Schema
    local option = { record = { default = value, rendered = value } }
    ---@type notedown.Schema
    return { map = { { type = 'string' }, option } }
end

return M
