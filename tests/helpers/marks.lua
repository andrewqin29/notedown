---@class notedown.test.Marks
---@field private marks notedown.test.MarkInfo[]
local Marks = {}
Marks.__index = Marks

---@return notedown.test.Marks
function Marks.new()
    local self = setmetatable({}, Marks)
    self.marks = {}
    return self
end

---@return notedown.test.MarkInfo[]
function Marks:get()
    table.sort(self.marks, function(a, b)
        return require('tests.helpers.details').__lt(a, b)
    end)
    return self.marks
end

---@param other notedown.test.Marks
---@return notedown.test.Marks
function Marks:extend(other)
    vim.list_extend(self.marks, other.marks)
    return self
end

---@param row notedown.test.Range|integer
---@param col notedown.test.Range|integer
---@param opts vim.api.keyset.set_extmark
function Marks:add(row, col, opts)
    ---@type notedown.test.MarkInfo
    ---@diagnostic disable-next-line: assign-type-mismatch
    local mark = opts
    mark.row = Marks.range(row)
    mark.col = Marks.range(col)
    self.marks[#self.marks + 1] = mark
end

---@private
---@param r notedown.test.Range|integer
---@return notedown.test.Range
function Marks.range(r)
    if type(r) == 'table' then
        return r
    elseif type(r) == 'number' then
        ---@type notedown.test.Range
        return { r }
    else
        error(('invalid range type: %s'):format(type(r)))
    end
end

return Marks
