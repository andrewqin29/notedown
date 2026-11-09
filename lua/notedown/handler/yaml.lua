local Context = require('notedown.request.context')
local Marks = require('notedown.lib.marks')
local ts = require('notedown.core.ts')

---@class notedown.handler.Yaml: notedown.Handler
local M = {}

---@param ctx notedown.handler.Context
---@return notedown.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('yaml', [[
        (block_sequence_item) @bullet

        ((double_quote_scalar) @link
            (#lua-match? @link "^\"%[%[.+%]%]\"$"))
    ]])
    ---@type table<string, notedown.Render>
    local renders = {
        bullet = require('notedown.render.yaml.bullet'),
        link = require('notedown.render.common.wiki'),
    }
    local context = Context.get(ctx.buf)
    if not context.config.yaml.enabled then
        return {}
    end
    local marks = Marks.new(context, true)
    context.view:nodes(ctx.root, query, function(capture, node)
        local render = renders[capture]
        assert(render, ('unhandled yaml capture: %s'):format(capture))
        render:execute(context, marks, node)
    end)
    return marks:get()
end

return M
