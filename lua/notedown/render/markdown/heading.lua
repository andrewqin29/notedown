local Base = require('notedown.render.base')
local str = require('notedown.lib.str')

---Headings: the #s hidden, and from ### down a bar in the heading's
---background color across the window. # and ## are drawn larger, as images
---(notes/heading_images.lua); their text color comes from the colorscheme.
---@class notedown.render.Heading: notedown.Render
---@field private config notedown.heading.Config
---@field private marker notedown.Node
---@field private level integer
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.heading
    if not self.config.enabled or self.context.conceal:hidden(self.node) then
        return false
    end
    local marker = self.node:child_at(0)
    if not marker then
        return false
    end
    self.marker = marker
    self.level = str.char_count(marker.text, '#')
    return true
end

---@protected
function Render:run()
    -- the #s and the space after them
    self.marks:over(self.config, 'head_icon', self.marker, {
        conceal = '',
    }, { 0, 0, 0, 1 })
    local background = self.config.backgrounds[self.level]
    if background then
        self.marks:add(
            self.config,
            'head_background',
            self.node.start_row,
            0,
            { line_hl_group = background }
        )
    end
end

return Render
