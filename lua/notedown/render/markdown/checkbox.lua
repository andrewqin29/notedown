local Base = require('notedown.render.base')
local str = require('notedown.lib.str')

---@class notedown.checkbox.Value
---@field node notedown.Node
---@field config notedown.checkbox.component.Config

---@class notedown.checkbox.Data
---@field marker notedown.Node
---@field checkbox notedown.Node
---@field icon string
---@field highlight string

---@class notedown.render.Checkbox: notedown.Render
---@field private config notedown.checkbox.Config
---@field private data notedown.checkbox.Data
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.checkbox
    if not self.config.enabled then
        return false
    end
    local marker = self.node:child_at(0)
    if not marker then
        return false
    end
    local value = self:get_value(marker)
    if not value then
        return false
    end
    if value.node.start_col ~= marker.end_col then
        return false
    end
    self.data = {
        marker = marker,
        checkbox = value.node,
        icon = value.config.icon,
        highlight = value.config.highlight,
    }
    return true
end

---@private
---@param marker notedown.Node
---@return notedown.checkbox.Value?
function Render:get_value(marker)
    local unchecked = marker:sibling('task_list_marker_unchecked')
    if unchecked then
        ---@type notedown.checkbox.Value
        return { node = unchecked, config = self.config.unchecked }
    end
    local checked = marker:sibling('task_list_marker_checked')
    if checked then
        ---@type notedown.checkbox.Value
        return { node = checked, config = self.config.checked }
    end
    return nil
end

---@protected
function Render:run()
    self:marker()
    self:checkbox()
end

---@private
function Render:marker()
    -- the list bullet is hidden
    -- https://github.com/tree-sitter-grammars/tree-sitter-markdown/issues/127
    local node = self.data.marker
    self.marks:over(self.config, 'check_icon', node, {
        conceal = '',
    }, { 0, str.spaces('start', node.text), 0, 0 })
end

---@private
function Render:checkbox()
    -- add 1 to end to account for space after checkbox
    local node = self.data.checkbox
    local row = node.start_row
    local start_col = node.start_col
    local end_col = node.end_col + 1
    local width = self.context:width(node) + 1

    local line = self:line()
        :pad(self.config.left_pad)
        :text(self.data.icon, self.data.highlight)
        :pad(self.config.right_pad)

    local overlay = line:sub(1, width)
    local used = overlay:width()
    if not overlay:empty() then
        self.marks:add(self.config, 'check_icon', row, start_col, {
            hl_mode = 'combine',
            virt_text = overlay:get(),
            virt_text_pos = 'overlay',
        })
    end

    local inline = line:sub(used + 1, line:width())
    if not inline:empty() then
        self.marks:add(self.config, 'check_icon', row, end_col, {
            hl_mode = 'combine',
            virt_text = inline:get(),
            virt_text_pos = 'inline',
        })
    end

    local space = width - used
    if space > 0 then
        self.marks:add(self.config, 'check_icon', row, end_col - space, {
            end_col = end_col,
            conceal = '',
        })
    end
end

return Render
