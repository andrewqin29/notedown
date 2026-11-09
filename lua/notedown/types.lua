---@meta

---@class (exact) notedown.UserConfig: notedown.partial.UserConfig, notedown.state.UserConfig
---@field overrides? notedown.overrides.UserConfig

---@class (exact) notedown.partial.UserConfig: notedown.base.UserConfig
---@field debounce? integer
---@field anti_conceal? notedown.anti.conceal.UserConfig
---@field bullet? notedown.bullet.UserConfig
---@field checkbox? notedown.checkbox.UserConfig
---@field dash? notedown.dash.UserConfig
---@field document? notedown.document.UserConfig
---@field heading? notedown.heading.UserConfig
---@field html? notedown.html.UserConfig
---@field indent? notedown.indent.UserConfig
---@field inline_highlight? notedown.inline.highlight.UserConfig
---@field link? notedown.link.UserConfig
---@field padding? notedown.padding.UserConfig
---@field paragraph? notedown.paragraph.UserConfig
---@field pipe_table? notedown.table.UserConfig
---@field quote? notedown.quote.UserConfig
---@field render? notedown.render.UserConfig
---@field sign? notedown.sign.UserConfig
---@field win_options? notedown.window.UserConfigs
---@field yaml? notedown.yaml.UserConfig

---@class (exact) notedown.state.UserConfig
---@field log_level? notedown.log.Level
---@field log_runtime? boolean
---@field notes? boolean
---@field file_types? string[]
---@field max_file_size? number
---@field ignore? fun(buf: integer): boolean
---@field nested? boolean
---@field change_events? string[]
---@field restart_highlighter? boolean
---@field injections? notedown.injection.UserConfigs
---@field patterns? notedown.pattern.UserConfigs
---@field on? notedown.on.UserConfig
---@field custom_handlers? table<string, notedown.Handler>

---@class (exact) notedown.anti.conceal.UserConfig
---@field enabled? boolean
---@field disabled_modes? notedown.Modes
---@field above? integer
---@field below? integer
---@field ignore? notedown.conceal.Ignore

---@class (exact) notedown.base.UserConfig
---@field enabled? boolean
---@field render_modes? notedown.Modes

---@class (exact) notedown.bullet.UserConfig: notedown.base.UserConfig
---@field icons? notedown.bullet.String
---@field ordered_icons? notedown.bullet.String
---@field left_pad? notedown.bullet.Integer
---@field right_pad? notedown.bullet.Integer
---@field highlight? notedown.bullet.String
---@field scope_highlight? notedown.bullet.String
---@field scope_priority? integer

---@class (exact) notedown.raw.UserConfig
---@field raw? string

---@class (exact) notedown.checkbox.UserConfig: notedown.base.UserConfig
---@field bullet? boolean
---@field left_pad? number
---@field right_pad? integer
---@field unchecked? notedown.checkbox.component.UserConfig
---@field checked? notedown.checkbox.component.UserConfig
---@field custom? table<string, notedown.checkbox.custom.UserConfig>
---@field scope_priority? integer

---@class (exact) notedown.checkbox.component.UserConfig
---@field icon? string
---@field highlight? string
---@field scope_highlight? string

---@class (exact) notedown.checkbox.custom.UserConfig: notedown.raw.UserConfig
---@field rendered? string
---@field highlight? string
---@field scope_highlight? string

---@class (exact) notedown.dash.UserConfig: notedown.base.UserConfig
---@field icon? string
---@field width? notedown.dash.Width
---@field left_margin? number
---@field priority? integer
---@field highlight? string

---@class (exact) notedown.document.UserConfig: notedown.base.UserConfig
---@field conceal? notedown.document.conceal.UserConfig

---@class (exact) notedown.document.conceal.UserConfig
---@field char_patterns? string[]
---@field line_patterns? string[]

---@class (exact) notedown.heading.UserConfig: notedown.base.UserConfig
---@field atx? boolean
---@field sign? boolean
---@field icons? notedown.heading.String
---@field position? notedown.heading.Position
---@field signs? string[]
---@field width? notedown.heading.Width|(notedown.heading.Width)[]
---@field left_margin? number|number[]
---@field left_pad? number|number[]
---@field right_pad? number|number[]
---@field min_width? integer|integer[]
---@field border? boolean|boolean[]
---@field border_virtual? boolean
---@field border_prefix? boolean
---@field above? string
---@field below? string
---@field backgrounds? string[]
---@field foregrounds? string[]
---@field custom? table<string, notedown.heading.Custom>

---@class (exact) notedown.html.UserConfig: notedown.base.UserConfig
---@field comment? notedown.html.comment.UserConfig
---@field tag? table<string, notedown.html.Tag>

---@class (exact) notedown.html.comment.UserConfig
---@field conceal? boolean
---@field text? notedown.html.comment.String
---@field highlight? string

---@class (exact) notedown.indent.UserConfig: notedown.base.UserConfig
---@field per_level? integer
---@field skip_level? integer
---@field skip_heading? boolean
---@field icon? string
---@field priority? integer
---@field highlight? string

---@alias notedown.injection.UserConfigs table<string, notedown.injection.UserConfig>

---@class (exact) notedown.injection.UserConfig
---@field enabled? boolean
---@field query? string

---@class (exact) notedown.inline.highlight.UserConfig: notedown.base.UserConfig
---@field highlight? string
---@field custom? table<string, notedown.inline.highlight.custom.UserConfig>

---@class (exact) notedown.inline.highlight.custom.UserConfig
---@field prefix? string
---@field highlight? string

---@class (exact) notedown.link.UserConfig: notedown.base.UserConfig
---@field footnote? notedown.link.footnote.UserConfig
---@field image? string
---@field image_custom? boolean
---@field email? string
---@field hyperlink? string
---@field highlight? string
---@field highlight_title? string
---@field wiki? notedown.link.wiki.UserConfig
---@field custom? table<string, notedown.link.custom.UserConfig>

---@class (exact) notedown.link.footnote.UserConfig
---@field enabled? boolean
---@field icon? string
---@field body? fun(ctx: notedown.link.footnote.Context): string?
---@field superscript? boolean
---@field prefix? string
---@field suffix? string

---@class (exact) notedown.link.wiki.UserConfig
---@field enabled? boolean
---@field icon? string
---@field conceal_destination? boolean
---@field body? fun(ctx: notedown.link.wiki.Context): notedown.mark.Text|string?
---@field highlight? string
---@field scope_highlight? string

---@class (exact) notedown.link.custom.UserConfig
---@field icon? string
---@field pattern? string
---@field kind? notedown.link.custom.Kind
---@field priority? integer
---@field highlight? string

---@class (exact) notedown.on.UserConfig
---@field attach? fun(ctx: notedown.on.attach.Context)
---@field initial? fun(ctx: notedown.on.render.Context)
---@field render? fun(ctx: notedown.on.render.Context)
---@field clear? fun(ctx: notedown.on.render.Context)

---@class (exact) notedown.overrides.UserConfig
---@field buflisted? table<boolean, notedown.partial.UserConfig>
---@field buftype? table<string, notedown.partial.UserConfig>
---@field filetype? table<string, notedown.partial.UserConfig>
---@field preview? notedown.partial.UserConfig

---@class (exact) notedown.padding.UserConfig
---@field highlight? string

---@class (exact) notedown.paragraph.UserConfig: notedown.base.UserConfig
---@field left_margin? notedown.paragraph.Number
---@field indent? notedown.paragraph.Number
---@field min_width? integer

---@alias notedown.pattern.UserConfigs table<string, notedown.pattern.UserConfig>

---@class (exact) notedown.pattern.UserConfig
---@field disable? boolean
---@field directives? notedown.directive.UserConfig[]

---@class (exact) notedown.directive.UserConfig
---@field id? integer
---@field name? string

---@class (exact) notedown.table.UserConfig: notedown.base.UserConfig
---@field preset? notedown.table.Preset
---@field cell? notedown.table.Cell
---@field wrap? boolean
---@field grid? boolean
---@field cell_offset? fun(ctx: notedown.table.cell.Context): integer
---@field padding? integer
---@field min_width? integer
---@field border? string[]
---@field border_enabled? boolean
---@field border_priority? integer
---@field border_virtual? boolean
---@field alignment_indicator? string
---@field head? string
---@field row? string
---@field style? notedown.table.Style

---@class (exact) notedown.quote.UserConfig: notedown.base.UserConfig
---@field icon? string|string[]
---@field repeat_linebreak? boolean
---@field highlight? string|string[]

---@class (exact) notedown.render.UserConfig
---@field diff? boolean

---@class (exact) notedown.sign.UserConfig
---@field enabled? boolean
---@field priority? integer
---@field highlight? string

---@alias notedown.window.UserConfigs table<string, notedown.window.UserConfig>

---@class (exact) notedown.window.UserConfig
---@field default? notedown.option.Value
---@field rendered? notedown.option.Value

---@class (exact) notedown.yaml.UserConfig: notedown.base.UserConfig
