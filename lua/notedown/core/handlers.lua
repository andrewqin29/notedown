local iter = require('notedown.lib.iter')
local log = require('notedown.core.log')

---@class (exact) notedown.Handler
---@field parse fun(ctx: notedown.handler.Context): notedown.Mark[]

---@class (exact) notedown.handler.Context
---@field buf integer
---@field root TSNode
---@field last boolean

---@class notedown.Handlers
local M = {}

---@private
---@type table<string, notedown.Handler>
M.builtin = {
    markdown = require('notedown.handler.markdown'),
    markdown_inline = require('notedown.handler.markdown_inline'),
}

---@param context notedown.request.Context
---@param parser vim.treesitter.LanguageTree
---@return notedown.Mark[]
function M.run(context, parser)
    local language_roots = {} ---@type table<string, TSNode[]>
    parser:for_each_tree(function(tree, language_tree)
        local root = tree:root()
        local language = language_tree:lang()
        if M.builtin[language] and context.view:overlaps(root) then
            local roots = language_roots[language]
            if not roots then
                roots = {}
                language_roots[language] = roots
            end
            roots[#roots + 1] = root
        end
    end)

    -- languages that run later will have more complete state
    local languages = vim.tbl_keys(language_roots) ---@type string[]
    local order = { markdown = 100 } ---@type table<string, integer>
    iter.list.sort(languages, function(language)
        return order[language] or 0
    end)

    local marks = {} ---@type notedown.Mark[]
    for _, language in ipairs(languages) do
        local roots = language_roots[language]
        for i, root in ipairs(roots) do
            M.tree(marks, language, {
                buf = context.buf,
                root = root,
                last = i == #roots,
            })
        end
    end
    return marks
end

---@private
---@param marks notedown.Mark[]
---@param language string
---@param ctx notedown.handler.Context
function M.tree(marks, language, ctx)
    log.buf('trace', 'Language', ctx.buf, language)
    vim.list_extend(marks, M.builtin[language].parse(ctx))
end

return M
