local Base = require('notedown.render.base')
local list = require('notedown.lib.list')
local ts = require('notedown.core.ts')

---@class notedown.quote.Data
---@field level integer
---@field icon string
---@field highlight string

---@class notedown.render.Quote: notedown.Render
---@field private config notedown.quote.Config
---@field private data notedown.quote.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.quote
    if not self.config.enabled then
        return false
    end
    local level = self.node:level_in('block_quote')
    self.data = {
        level = level,
        icon = self.config.icon,
        highlight = assert(list.cycle(self.config.highlight, level)),
    }
    return true
end

---@protected
function Render:run()
    self:markers()
end

---@private
function Render:markers()
    -- stylua: ignore
    local query = ts.parse('markdown', [[
        (block_quote_marker) @marker
        (block_continuation) @continuation
    ]])
    self.context.view:nodes(self.node:get(), query, function(capture, node)
        if capture == 'marker' then
            -- marker nodes are a single '>' at the start of a block quote
            -- overlay the only range if it is at the current level
            if node:level_in('block_quote') == self.data.level then
                self:marker(node, 1)
            end
        elseif capture == 'continuation' then
            -- continuation nodes are a group of '>'s inside a block quote
            -- overlay the range of the one at the current level if it exists
            self:marker(node, self.data.level)
        else
            error(('unhandled quote capture: %s'):format(capture))
        end
    end)
end

---@private
---@param node notedown.Node
---@param index integer
function Render:marker(node, index)
    local range = node:find('>')[index]
    if not range then
        return
    end
    self.marks:add(self.config, 'quote', range[1], range[2], {
        end_row = range[3],
        end_col = range[4],
        virt_text = { { self.data.icon, self.data.highlight } },
        virt_text_pos = 'overlay',
        -- on wrapped lines too, which start under the text (notes/blocks.lua)
        virt_text_repeat_linebreak = true,
    })
end

return Render
