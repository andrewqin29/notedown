local Base = require('notedown.render.base')

---@class notedown.render.inline.Highlight: notedown.Render
---@field private config notedown.inline.highlight.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.inline_highlight
    return self.config.enabled
end

---@protected
function Render:run()
    for _, range in ipairs(self.node:find('==[^=]+==')) do
        local top_level = self:top_level(range[1], range[2])
            and self:top_level(range[3], range[4])
        if top_level then
            -- hide first 2 equal signs
            self:hide(range[1], range[2], range[2] + 2)
            -- hide last 2 equal signs
            self:hide(range[3], range[4] - 2, range[4])

            -- highlight contents
            self.marks:add(self.config, false, range[1], range[2], {
                end_row = range[3],
                end_col = range[4],
                hl_group = self.config.highlight,
            })
        end
    end
end

---@private
---@param row integer
---@param col integer
---@return boolean
function Render:top_level(row, col)
    local node = vim.treesitter.get_node({
        bufnr = self.context.buf,
        pos = { row, col },
        ignore_injections = false,
    })
    return node and node:type() == 'inline' or false
end

---@private
---@param row integer
---@param start_col integer
---@param end_col integer
function Render:hide(row, start_col, end_col)
    self.marks:add(self.config, true, row, start_col, {
        end_col = end_col,
        conceal = '',
    })
end

return Render
