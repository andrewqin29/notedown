---@class notedown.Range: Range2
---@field [1] integer start
---@field [2] integer end

---@class notedown.Interval
local M = {}

---@param range notedown.Range
---@param exclusive? boolean
---@return boolean
function M.valid(range, exclusive)
    if exclusive then
        return range[1] < range[2]
    else
        return range[1] <= range[2]
    end
end

---noncommutative
---@param a notedown.Range
---@param b notedown.Range
---@return boolean
function M.contains(a, b)
    return a[1] <= b[1] and a[2] >= b[2]
end

---commutative
---@param a notedown.Range
---@param b notedown.Range
---@param exclusive? boolean
---@return notedown.Range?
function M.overlap(a, b, exclusive)
    ---@type notedown.Range
    local result = {
        math.max(a[1], b[1]),
        math.min(a[2], b[2]),
    }
    return M.valid(result, exclusive) and result or nil
end

---@param ranges notedown.Range[]
---@return notedown.Range[]
function M.coalesce(ranges)
    M.sort(ranges)
    local result = {} ---@type notedown.Range[]
    result[#result + 1] = ranges[1]
    for i = 2, #ranges do
        local range, last = ranges[i], result[#result]
        if range[1] <= last[2] + 1 then
            last[2] = math.max(last[2], range[2])
        else
            result[#result + 1] = range
        end
    end
    return result
end

---@param ranges notedown.Range[]
function M.sort(ranges)
    table.sort(ranges, function(a, b)
        return a[1] == b[1] and a[2] < b[2] or a[1] < b[1]
    end)
end

return M
