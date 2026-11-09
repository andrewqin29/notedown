local interval = require('notedown.lib.interval')

---@class notedown.request.highlights.Line
---@field hidden boolean
---@field conceals notedown.request.highlights.Conceal[]
---@field groups notedown.request.highlights.Group[]

---@class notedown.request.highlights.Entry
---@field hidden? boolean
---@field conceal? notedown.request.highlights.Conceal
---@field group? notedown.request.highlights.Group

---@class notedown.request.highlights.Conceal: notedown.Range
---@field replacement string
---@field blocks integer

---@class notedown.request.highlights.Group: notedown.Range
---@field priority integer
---@field highlight notedown.mark.Hl

---@class notedown.request.Highlights
---@field private buf integer
---@field private view notedown.request.View
---@field private computed boolean
---@field private lines table<integer, notedown.request.highlights.Line>
local Highlights = {}
Highlights.__index = Highlights

---@param buf integer
---@param view notedown.request.View
---@return notedown.request.Highlights
function Highlights.new(buf, view)
    local self = setmetatable({}, Highlights)
    self.buf = buf
    self.view = view
    self.computed = false
    self.lines = {}
    return self
end

---@param row integer
---@param entry notedown.request.highlights.Entry
function Highlights:add(row, entry)
    if not self.lines[row] then
        self.lines[row] = { hidden = false, conceals = {}, groups = {} }
    end
    local line = self.lines[row]
    if entry.hidden then
        line.hidden = entry.hidden
    end
    if entry.conceal then
        if interval.valid(entry.conceal, true) then
            line.conceals[#line.conceals + 1] = entry.conceal
            line.conceals = Highlights.coalesce_conceals(line.conceals)
        end
    end
    if entry.group then
        if interval.valid(entry.group, true) then
            line.groups[#line.groups + 1] = entry.group
            table.sort(line.groups, function(a, b)
                if a.priority ~= b.priority then
                    return a.priority < b.priority
                else
                    return a.highlight < b.highlight
                end
            end)
        end
    end
end

---@private
---@param conceals notedown.request.highlights.Conceal[]
---@return notedown.request.highlights.Conceal[]
function Highlights.coalesce_conceals(conceals)
    interval.sort(conceals)
    local result = {} ---@type notedown.request.highlights.Conceal[]
    result[#result + 1] = conceals[1]
    for i = 2, #conceals do
        local conceal, last = conceals[i], result[#result]
        if conceal[1] <= last[2] then
            last[2] = math.max(last[2], conceal[2])
            last.replacement = last.replacement .. conceal.replacement
            last.blocks = last.blocks + conceal.blocks
        else
            result[#result + 1] = conceal
        end
    end
    return result
end

---@param row integer
---@return notedown.request.highlights.Line
function Highlights:line(row)
    if not self.computed then
        self.computed = true
        self:compute()
    end
    local line = self.lines[row]
    if not line then
        line = { hidden = false, conceals = {}, groups = {} }
    end
    return line
end

---Cached row level implementation of vim.treesitter.get_captures_at_pos
---@private
function Highlights:compute()
    if not vim.treesitter.highlighter.active[self.buf] then
        return
    end
    local parser = vim.treesitter.get_parser(self.buf)
    if not parser then
        return
    end
    parser:for_each_tree(function(tree, language_tree)
        self:tree(language_tree:lang(), tree:root())
    end)
end

---@private
---@param language string
---@param root TSNode
function Highlights:tree(language, root)
    if not self.view:overlaps(root) then
        return
    end
    if not vim.tbl_contains({ 'markdown', 'markdown_inline' }, language) then
        return
    end
    local query = vim.treesitter.query.get(language, 'highlights')
    if not query then
        return
    end
    self.view:query(root, query, function(id, node, data)
        local row, start_col, _, end_col = Highlights.range(id, data, node)
        if data.conceal_lines then
            self:add(row, { hidden = true })
        end
        if data.conceal then
            self:add(row, {
                conceal = {
                    start_col,
                    end_col,
                    replacement = data.conceal,
                    blocks = 1,
                },
            })
        end
        self:add(row, {
            group = {
                start_col,
                end_col,
                priority = Highlights.priority(id, data),
                highlight = '@' .. query.captures[id] .. '.' .. language,
            },
        })
    end)
end

---@private
---@param id integer
---@param data vim.treesitter.query.TSMetadata
---@param node TSNode
---@return integer, integer, integer, integer
function Highlights.range(id, data, node)
    local range = (data[id] or {}).range or data.range or { node:range() }
    local offset = (data[id] or {}).offset or data.offset or { 0, 0, 0, 0 }
    return range[1] + tonumber(offset[1]),
        range[2] + tonumber(offset[2]),
        range[3] + tonumber(offset[3]),
        range[4] + tonumber(offset[4])
end

---@private
---@param id integer
---@param data vim.treesitter.query.TSMetadata
---@return integer
function Highlights.priority(id, data)
    return tonumber((data[id] or {}).priority or data.priority) or 100
end

return Highlights
