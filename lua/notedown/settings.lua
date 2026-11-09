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
    indent = 'indent',
    link = 'link',
    quote = 'quote',
    sign = 'sign',
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
    --   indent
    --   link
    --   quote
    --   sign
    --   table_border
    --   virtual_lines
    ignore = {
        indent = true,
        sign = true,
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

---@class (exact) notedown.raw.Config
---@field raw string

---@class notedown.checkbox.Settings
M.checkbox = {}

---@class (exact) notedown.checkbox.Config: notedown.base.Config
---@field bullet boolean
---@field left_pad number
---@field right_pad integer
---@field unchecked notedown.checkbox.component.Config
---@field checked notedown.checkbox.component.Config
---@field custom table<string, notedown.checkbox.custom.Config>
---@field scope_priority? integer

---@class (exact) notedown.checkbox.component.Config
---@field icon string
---@field highlight string
---@field scope_highlight? string

---@class (exact) notedown.checkbox.custom.Config: notedown.raw.Config
---@field rendered string
---@field highlight string
---@field scope_highlight? string

---@type notedown.checkbox.Config
M.checkbox.default = {
    -- Checkboxes are a special instance of a 'list_item' that start with a 'shortcut_link'.
    -- There are two special states for unchecked & checked defined in the markdown grammar.

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
    -- Define custom checkbox states, more involved, not part of the markdown grammar.
    -- As a result this requires neovim >= 0.10.0 since it relies on 'inline' extmarks.
    -- The key is for healthcheck and to allow users to change its values, value type below.
    -- | raw             | matched against the raw text of a 'shortcut_link'           |
    -- | rendered        | replaces the 'raw' value when rendering                     |
    -- | highlight       | highlight for the 'rendered' icon                           |
    -- | scope_highlight | optional highlight for item associated with custom checkbox |
    -- stylua: ignore
    custom = {
        todo = { raw = '[-]', rendered = '󰥔 ', highlight = 'NotedownTodo', scope_highlight = nil },
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
    ---@type notedown.Schema
    local custom = {
        record = {
            raw = { type = 'string' },
            rendered = { type = 'string' },
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
        custom = { map = { { type = 'string' }, custom } },
        scope_priority = { optional = true, type = 'number' },
    })
end

---@class notedown.completions.Settings
M.completions = {}

---@class (exact) notedown.completions.Config
---@field blink notedown.completion.Config
---@field coq notedown.completion.Config
---@field lsp notedown.completion.Config
---@field filter notedown.completion.filter.Config

---@class (exact) notedown.completion.Config
---@field enabled boolean

---@class (exact) notedown.completion.filter.Config
---@field checkbox fun(value: notedown.checkbox.custom.Config): boolean

---@type notedown.completions.Config
M.completions.default = {
    -- Settings for blink.cmp completions source
    blink = { enabled = false },
    -- Settings for coq_nvim completions source
    coq = { enabled = false },
    -- Settings for in-process language server completions
    lsp = { enabled = false },
    filter = {
        checkbox = function()
            return true
        end,
    },
}

---@return notedown.Schema
function M.completions.schema()
    ---@type notedown.Schema
    local completion = { record = { enabled = { type = 'boolean' } } }
    ---@type notedown.Schema
    return {
        record = {
            blink = completion,
            coq = completion,
            lsp = completion,
            filter = {
                record = {
                    checkbox = { type = 'function' },
                },
            },
        },
    }
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

---@class notedown.handlers.Settings
M.handlers = {}

---@class (exact) notedown.Handler
---@field extends? boolean
---@field parse fun(ctx: notedown.handler.Context): notedown.Mark[]

---@class (exact) notedown.handler.Context
---@field buf integer
---@field root TSNode
---@field last boolean

---@type table<string, notedown.Handler>
M.handlers.default = {
    -- Mapping from treesitter language to user defined handlers.
    -- @see [Custom Handlers](doc/custom-handlers.md)
}

---@return notedown.Schema
function M.handlers.schema()
    ---@type notedown.Schema
    local handler = {
        record = {
            extends = { optional = true, type = 'boolean' },
            parse = { type = 'function' },
        },
    }
    ---@type notedown.Schema
    return { map = { { type = 'string' }, handler } }
end

---@class notedown.heading.Settings
M.heading = {}

---@class (exact) notedown.heading.Config: notedown.base.Config
---@field atx boolean
---@field sign boolean
---@field icons notedown.heading.String
---@field position notedown.heading.Position
---@field signs string[]
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
    -- Turn on / off sign column related rendering.
    sign = true,
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
    -- Added to the sign column if enabled.
    -- Output is evaluated by `cycle(value, context.level)`.
    signs = { '󰫎 ' },
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
        sign = { type = 'boolean' },
        icons = {
            union = { { list = { type = 'string' } }, { type = 'function' } },
        },
        position = { enum = M.heading.position },
        signs = { list = { type = 'string' } },
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

---@class notedown.html.Settings
M.html = {}

---@class (exact) notedown.html.Config: notedown.base.Config
---@field comment notedown.html.comment.Config
---@field tag table<string, notedown.html.Tag>

---@class (exact) notedown.html.comment.Config
---@field conceal boolean
---@field text? notedown.html.comment.String
---@field highlight string

---@class (exact) notedown.html.comment.Context
---@field text string

---@alias notedown.html.comment.String
---| string
---| fun(ctx: notedown.html.comment.Context): string?

---@class (exact) notedown.html.Tag
---@field icon? string
---@field highlight? string
---@field scope_highlight? string

---@type notedown.html.Config
M.html.default = {
    -- Turn on / off all HTML rendering.
    enabled = true,
    -- Additional modes to render HTML.
    render_modes = false,
    comment = {
        -- Useful context to have when evaluating values.
        -- | text | text value of the comment node |

        -- Turn on / off HTML comment concealing.
        conceal = true,
        -- Text to inline before the concealed comment.
        -- Output is evaluated depending on the type.
        -- | function | `value(context)` |
        -- | string   | `value`          |
        -- | nil      | nothing          |
        text = nil,
        -- Highlight for the inlined text.
        highlight = 'NotedownHtmlComment',
    },
    -- HTML tags whose start and end will be hidden and icon shown.
    -- The key is matched against the tag name, value type below.
    -- | icon            | optional icon inlined at start of tag           |
    -- | highlight       | optional highlight for the icon                 |
    -- | scope_highlight | optional highlight for item associated with tag |
    tag = {},
}

---@return notedown.Schema
function M.html.schema()
    ---@type notedown.Schema
    local tag = {
        record = {
            icon = { optional = true, type = 'string' },
            highlight = { optional = true, type = 'string' },
            scope_highlight = { optional = true, type = 'string' },
        },
    }
    return M.base.schema({
        comment = {
            record = {
                conceal = { type = 'boolean' },
                text = {
                    optional = true,
                    union = { { type = 'string' }, { type = 'function' } },
                },
                highlight = { type = 'string' },
            },
        },
        tag = { map = { { type = 'string' }, tag } },
    })
end

---@class notedown.indent.Settings
M.indent = {}

---@class (exact) notedown.indent.Config: notedown.base.Config
---@field per_level integer
---@field skip_level integer
---@field skip_heading boolean
---@field icon string
---@field priority integer
---@field highlight string

---@type notedown.indent.Config
M.indent.default = {
    -- Mimic org-indent-mode behavior by indenting everything under a heading based on the
    -- level of the heading. Indenting starts from level 2 headings onward by default.

    -- Turn on / off org-indent-mode.
    enabled = false,
    -- Additional modes to render indents.
    render_modes = false,
    -- Amount of additional padding added for each heading level.
    per_level = 2,
    -- Heading levels <= this value will not be indented.
    -- Use 0 to begin indenting from the very first level.
    skip_level = 1,
    -- Do not indent heading titles, only the body.
    skip_heading = false,
    -- Prefix added when indenting, one per level.
    icon = '▎',
    -- Priority to assign to extmarks.
    priority = 0,
    -- Applied to icon.
    highlight = 'NotedownIndent',
}

---@return notedown.Schema
function M.indent.schema()
    return M.base.schema({
        per_level = { type = 'number' },
        skip_level = { type = 'number' },
        skip_heading = { type = 'boolean' },
        icon = { type = 'string' },
        priority = { type = 'number' },
        highlight = { type = 'string' },
    })
end

---@class notedown.injections.Settings
M.injections = {}

---@alias notedown.injection.Configs table<string, notedown.injection.Config>

---@class (exact) notedown.injection.Config
---@field enabled boolean
---@field query string

---@type notedown.injection.Configs
M.injections.default = {
    -- Out of the box language injections for known filetypes that allow markdown to be interpreted
    -- in specified locations, see :h treesitter-language-injections.
    -- Set enabled to false in order to disable.

    gitcommit = {
        enabled = true,
        query = [[
            ((message) @injection.content
                (#set! injection.combined)
                (#set! injection.include-children)
                (#set! injection.language "markdown"))
        ]],
    },
}

---@return notedown.Schema
function M.injections.schema()
    ---@type notedown.Schema
    local injection = {
        record = {
            enabled = { type = 'boolean' },
            query = { type = 'string' },
        },
    }
    ---@type notedown.Schema
    return { map = { { type = 'string' }, injection } }
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

---@class notedown.link.Settings
M.link = {}

---@class (exact) notedown.link.Config: notedown.base.Config
---@field footnote notedown.link.footnote.Config
---@field image string
---@field image_custom boolean
---@field email string
---@field hyperlink string
---@field highlight string
---@field highlight_title string
---@field wiki notedown.link.wiki.Config
---@field custom table<string, notedown.link.custom.Config>

---@class (exact) notedown.link.footnote.Context
---@field text string

---@class (exact) notedown.link.footnote.Config
---@field enabled boolean
---@field icon string
---@field body fun(ctx: notedown.link.footnote.Context): string?
---@field superscript boolean
---@field prefix string
---@field suffix string

---@class (exact) notedown.link.wiki.Context
---@field buf integer
---@field row integer
---@field start_col integer
---@field end_col integer
---@field destination string
---@field alias? string

---@class (exact) notedown.link.wiki.Config
---@field enabled boolean
---@field icon string
---@field conceal_destination boolean
---@field body fun(ctx: notedown.link.wiki.Context): notedown.mark.Text|string?
---@field highlight string
---@field scope_highlight? string

---@class (exact) notedown.link.custom.Config
---@field icon string
---@field pattern string
---@field kind? notedown.link.custom.Kind
---@field priority? integer
---@field highlight? string

---@enum notedown.link.custom.Kind
M.link.kind = {
    pattern = 'pattern',
    prefix = 'prefix',
    suffix = 'suffix',
    url = 'url',
}

---@type notedown.link.Config
M.link.default = {
    -- Turn on / off inline link icon rendering.
    enabled = true,
    -- Additional modes to render links.
    render_modes = false,
    -- How to handle footnote links, start with a '^'.
    footnote = {
        -- Turn on / off footnote rendering.
        enabled = true,
        -- Inlined with content.
        icon = '󰯔 ',
        -- Custom processing for footnote body to show.
        -- Runs before prefix / suffix are added and superscript processing.
        body = function(ctx)
            return ctx.text
        end,
        -- Replace value with superscript equivalent.
        superscript = true,
        -- Added before link content.
        prefix = '',
        -- Added after link content.
        suffix = '',
    },
    -- Inlined with 'image' elements.
    image = '󰥶 ',
    -- Check custom for 'image' elements.
    image_custom = true,
    -- Inlined with 'email_autolink' elements.
    email = '󰀓 ',
    -- Fallback icon for 'inline_link' and 'uri_autolink' elements.
    hyperlink = '󰌹 ',
    -- Applies to the inlined icon as a fallback.
    highlight = 'NotedownLink',
    -- Applies to the link title.
    highlight_title = 'NotedownLinkTitle',
    -- Applies to WikiLink elements.
    wiki = {
        -- Turn on / off WikiLink rendering.
        enabled = true,
        -- Inlined with content.
        icon = '󱗖 ',
        -- Hide destination if there is an alias.
        conceal_destination = true,
        -- Custom processing for WikiLink body to show.
        body = function()
            return nil
        end,
        -- Applies to the inlined icon.
        highlight = 'NotedownWikiLink',
        -- Highlight for item associated with the WikiLink.
        scope_highlight = nil,
    },
    -- Define custom destination patterns so icons can quickly inform you of what a link
    -- contains. Applies to 'image', 'inline_link', 'uri_autolink', and WikiLink nodes.
    -- When multiple patterns match a link the one with the longer pattern is used.
    -- The key is for healthcheck and to allow users to change its values, value type below.
    -- | icon      | gets inlined before the link text                               |
    -- | pattern   | matched against the destination text                            |
    -- | kind      | optional determines how pattern is checked                      |
    -- |           | pattern | @see :h lua-patterns, is the default if not set       |
    -- |           | prefix  | @see :h vim.startswith()                              |
    -- |           | suffix  | @see :h vim.endswith()                                |
    -- |           | url     | similar to pattern with additional prefix checks      |
    -- | priority  | optional used when multiple match, uses pattern length if empty |
    -- | highlight | optional highlight for 'icon', uses fallback highlight if empty |
    -- stylua: ignore
    custom = {
        web = { icon = '󰖟 ', pattern = '^http' },
        apple = { icon = ' ', pattern = 'apple%.com', kind = 'url' },
        discord = { icon = '󰙯 ', pattern = 'discord%.com', kind = 'url' },
        github = { icon = '󰊤 ', pattern = 'github%.com', kind = 'url' },
        gitlab = { icon = '󰮠 ', pattern = 'gitlab%.com', kind = 'url' },
        google = { icon = '󰊭 ', pattern = 'google%.com', kind = 'url' },
        hackernews = { icon = ' ', pattern = 'ycombinator%.com', kind = 'url' },
        linkedin = { icon = '󰌻 ', pattern = 'linkedin%.com', kind = 'url' },
        microsoft = { icon = ' ', pattern = 'microsoft%.com', kind = 'url' },
        neovim = { icon = ' ', pattern = 'neovim%.io', kind = 'url' },
        reddit = { icon = '󰑍 ', pattern = 'reddit%.com', kind = 'url' },
        slack = { icon = '󰒱 ', pattern = 'slack%.com', kind = 'url' },
        stackoverflow = { icon = '󰓌 ', pattern = 'stackoverflow%.com', kind = 'url' },
        steam = { icon = ' ', pattern = 'steampowered%.com', kind = 'url' },
        twitter = { icon = ' ', pattern = 'twitter%.com', kind = 'url' },
        wikipedia = { icon = '󰖬 ', pattern = 'wikipedia%.org', kind = 'url' },
        x = { icon = ' ', pattern = 'x%.com', kind = 'url' },
        youtube = { icon = '󰗃 ', pattern = 'youtube[^.]*%.com', kind = 'url' },
        youtube_short = { icon = '󰗃 ', pattern = 'youtu%.be', kind = 'url' },
    },
}

---@return notedown.Schema
function M.link.schema()
    ---@type notedown.Schema
    local pattern = {
        record = {
            icon = { type = 'string' },
            pattern = { type = 'string' },
            kind = { optional = true, enum = M.link.kind },
            priority = { optional = true, type = 'number' },
            highlight = { optional = true, type = 'string' },
        },
    }
    return M.base.schema({
        footnote = {
            record = {
                enabled = { type = 'boolean' },
                icon = { type = 'string' },
                body = { type = 'function' },
                superscript = { type = 'boolean' },
                prefix = { type = 'string' },
                suffix = { type = 'string' },
            },
        },
        image = { type = 'string' },
        image_custom = { type = 'boolean' },
        email = { type = 'string' },
        hyperlink = { type = 'string' },
        highlight = { type = 'string' },
        highlight_title = { type = 'string' },
        wiki = {
            record = {
                enabled = { type = 'boolean' },
                icon = { type = 'string' },
                conceal_destination = { type = 'boolean' },
                body = { type = 'function' },
                highlight = { type = 'string' },
                scope_highlight = { optional = true, type = 'string' },
            },
        },
        custom = { map = { { type = 'string' }, pattern } },
    })
end

---@class notedown.on.Settings
M.on = {}

---@class (exact) notedown.on.Config
---@field attach fun(ctx: notedown.on.attach.Context)
---@field initial fun(ctx: notedown.on.render.Context)
---@field render fun(ctx: notedown.on.render.Context)
---@field clear fun(ctx: notedown.on.render.Context)

---@class (exact) notedown.on.attach.Context
---@field buf integer

---@class (exact) notedown.on.render.Context
---@field buf integer
---@field win integer

---@type notedown.on.Config
M.on.default = {
    -- Called when plugin initially attaches to a buffer.
    attach = function() end,
    -- Called before adding marks to the buffer for the first time.
    initial = function() end,
    -- Called after plugin renders a buffer.
    render = function() end,
    -- Called after plugin clears a buffer.
    clear = function() end,
}

---@return notedown.Schema
function M.on.schema()
    ---@type notedown.Schema
    return {
        record = {
            attach = { type = 'function' },
            initial = { type = 'function' },
            render = { type = 'function' },
            clear = { type = 'function' },
        },
    }
end

---@class notedown.overrides.Settings
M.overrides = {}

---@class (exact) notedown.overrides.Config
---@field buflisted table<boolean, notedown.partial.UserConfig>
---@field buftype table<string, notedown.partial.UserConfig>
---@field filetype table<string, notedown.partial.UserConfig>
---@field preview notedown.partial.UserConfig

---@type notedown.overrides.Config
M.overrides.default = {
    -- More granular configuration mechanism, allows different aspects of buffers to have their own
    -- behavior. Values default to the top level configuration if no override is provided. Supports
    -- the following fields:
    --   enabled, render_modes, debounce, anti_conceal, bullet, checkbox, dash,
    --   document, heading, html, indent, inline_highlight, link, padding, paragraph,
    --   pipe_table, quote, sign, win_options, yaml

    -- Override for different buflisted values, @see :h 'buflisted'.
    buflisted = {},
    -- Override for different buftype values, @see :h 'buftype'.
    buftype = {
        nofile = {
            render_modes = true,
            sign = { enabled = false },
        },
    },
    -- Override for different filetype values, @see :h 'filetype'.
    filetype = {},
    -- Override for preview buffer.
    preview = {
        render_modes = true,
    },
}

---@return notedown.Schema
function M.overrides.schema()
    local Config = require('notedown.lib.config')
    ---@type notedown.Schema
    return {
        record = {
            buflisted = { map = { { type = 'boolean' }, Config.schema({}) } },
            buftype = { map = { { type = 'string' }, Config.schema({}) } },
            filetype = { map = { { type = 'string' }, Config.schema({}) } },
            preview = Config.schema({}),
        },
    }
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

---@class notedown.patterns.Settings
M.patterns = {}

---@alias notedown.pattern.Configs table<string, notedown.pattern.Config>

---@class (exact) notedown.pattern.Config
---@field disable boolean
---@field directives notedown.directive.Config[]

---@class (exact) notedown.directive.Config
---@field id integer
---@field name string

---@type notedown.pattern.Configs
M.patterns.default = {
    -- Highlight patterns to disable for filetypes, i.e. lines concealed around code blocks

    markdown = {
        disable = true,
        directives = {
            { id = 17, name = 'conceal_lines' },
            { id = 18, name = 'conceal_lines' },
        },
    },
}

---@return notedown.Schema
function M.patterns.schema()
    ---@type notedown.Schema
    local directive = {
        record = {
            id = { type = 'number' },
            name = { type = 'string' },
        },
    }
    ---@type notedown.Schema
    local pattern = {
        record = {
            disable = { type = 'boolean' },
            directives = { list = directive },
        },
    }
    ---@type notedown.Schema
    return { map = { { type = 'string' }, pattern } }
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

---@class notedown.sign.Settings
M.sign = {}

---@class (exact) notedown.sign.Config
---@field enabled boolean
---@field priority? integer
---@field highlight string

---@type notedown.sign.Config
M.sign.default = {
    -- Turn on / off sign rendering.
    enabled = true,
    -- Priority to assign to sign.
    priority = nil,
    -- Applies to background of sign text.
    highlight = 'NotedownSign',
}

---@return notedown.Schema
function M.sign.schema()
    ---@type notedown.Schema
    return {
        record = {
            enabled = { type = 'boolean' },
            priority = { optional = true, type = 'number' },
            highlight = { type = 'string' },
        },
    }
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

---@class notedown.yaml.Settings
M.yaml = {}

---@class (exact) notedown.yaml.Config: notedown.base.Config

---@type notedown.yaml.Config
M.yaml.default = {
    -- Turn on / off all yaml rendering.
    enabled = true,
    -- Additional modes to render yaml.
    render_modes = false,
}

---@return notedown.Schema
function M.yaml.schema()
    return M.base.schema({})
end

return M
