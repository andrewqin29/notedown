local Base = require('notedown.render.base')
local list = require('notedown.lib.list')
local str = require('notedown.lib.str')

---List bullets: an icon by how deeply the list is nested (renumbered numbers
---for ordered lists), with the item moved left_pad columns in.
---@class notedown.bullet.Data
---@field marker notedown.Node
---@field root? notedown.Node
---@field icon string

---@class notedown.render.Bullet: notedown.Render
---@field private config notedown.bullet.Config
---@field private data notedown.bullet.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.bullet
    if not self.config.enabled then
        return false
    end
    local marker = self.node:child_at(0)
    if not marker then
        return false
    end
    local level, root = self.node:level_in('list')
    local icon ---@type string
    if marker.type == 'list_marker_dot' or marker.type == 'list_marker_parenthesis' then
        -- the number as written, or the item's position for lists of 1. 1. 1.
        local value = vim.trim(marker.text)
        local number = tonumber(value:sub(1, #value - 1)) or 0
        icon = ('%d.'):format(number > 1 and number or self.node:sibling_count('list_item'))
    else
        icon = assert(list.cycle(self.config.icons, level))
    end
    self.data = { marker = marker, root = root, icon = icon }
    return true
end

---@protected
function Render:run()
    self:marker()
    self:padding()
end

---@private
function Render:marker()
    -- https://github.com/tree-sitter-grammars/tree-sitter-markdown/issues/127
    local node = self.data.marker
    local text = str.pad(str.spaces('start', node.text)) .. self.data.icon
    local overflow = str.width(text) > str.width(node.text)
    self.marks:over(self.config, 'bullet', node, {
        virt_text = { { text, self.config.highlight } },
        virt_text_pos = overflow and 'inline' or 'overlay',
        conceal = overflow and '' or nil,
    })
end

---@private
function Render:padding()
    local padding = self:line():pad(self.config.left_pad):get()
    if #padding == 0 then
        return
    end
    local root = self.data.root
    for row = self.node.start_row, self:end_row() - 1 do
        local col = root and root.start_col or self.node.start_col
        self.marks:add(self.config, false, row, col, {
            priority = 100,
            virt_text = padding,
            virt_text_pos = 'inline',
        })
    end
end

---@private
---@return integer
function Render:end_row()
    local sub_list = self.node:child('list')
    if sub_list then
        return sub_list.start_row
    end
    local root = self.data.root
    if not root then
        return self.node.end_row
    end
    -- on the last item of the root list ignore the last line if empty
    local row = self.node.end_row
    local _, line = root:line('last', 0)
    local ignore_last = root.end_row == row and str.width(line) == 0
    return row - (ignore_last and 1 or 0)
end

return Render
