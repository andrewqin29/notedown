---@class notedown.Iter
local M = {}

---@class notedown.iter.List
M.list = {}

---@generic T, U
---@param values T[]
---@param f fun(value: T): U
---@return U[]
function M.list.map(values, f)
    local result = {}
    for _, value in ipairs(values) do
        result[#result + 1] = f(value)
    end
    return result
end

---@generic T
---@param values T[]
---@param f fun(value: T): integer
function M.list.sort(values, f)
    table.sort(values, function(a, b)
        return f(a) < f(b)
    end)
end

return M
