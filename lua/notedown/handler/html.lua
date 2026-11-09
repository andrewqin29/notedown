local Context = require('notedown.request.context')
local Marks = require('notedown.lib.marks')
local ts = require('notedown.core.ts')

---@class notedown.handler.Html: notedown.Handler
local M = {}

---@param ctx notedown.handler.Context
---@return notedown.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('html', [[
        (comment) @comment
        (element) @tag
    ]])
    ---@type table<string, notedown.Render>
    local renders = {
        comment = require('notedown.render.html.comment'),
        tag = require('notedown.render.html.tag'),
    }
    local context = Context.get(ctx.buf)
    if not context.config.html.enabled then
        return {}
    end
    local marks = Marks.new(context, true)
    context.view:nodes(ctx.root, query, function(capture, node)
        local render = renders[capture]
        assert(render, ('unhandled html capture: %s'):format(capture))
        render:execute(context, marks, node)
    end)
    return marks:get()
end

return M
