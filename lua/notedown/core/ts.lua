
---@class notedown.Ts
local M = {}

---@private
---@type table<string, vim.treesitter.Query>
M.queries = {}

---@param language string
---@param query string
---@return vim.treesitter.Query
function M.parse(language, query)
    local result = M.queries[query]
    if not result then
        result = vim.treesitter.query.parse(language, query)
        M.queries[query] = result
    end
    return result
end

return M
