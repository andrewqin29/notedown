local Context = require('notedown.request.context')
local Marks = require('notedown.lib.marks')
local ts = require('notedown.core.ts')

---@class notedown.handler.MarkdownInline: notedown.Handler
local M = {}

---@param ctx notedown.handler.Context
---@return notedown.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('markdown_inline', [[

        ((inline) @highlight
            (#lua-match? @highlight "==[^=]+=="))

        [
            (email_autolink)
            (full_reference_link)
            (image)
            (inline_link)
            (uri_autolink)
        ] @link

        (shortcut_link) @shortcut
    ]])
    ---@type table<string, notedown.Render>
    local renders = {
        highlight = require('notedown.render.inline.highlight'),
        link = require('notedown.render.inline.link'),
        shortcut = require('notedown.render.inline.shortcut'),
    }
    local context = Context.get(ctx.buf)
    local marks = Marks.new(context, true)
    context.view:nodes(ctx.root, query, function(capture, node)
        local render = renders[capture]
        assert(render, ('unhandled inline capture: %s'):format(capture))
        render:execute(context, marks, node)
    end)
    return marks:get()
end

return M
