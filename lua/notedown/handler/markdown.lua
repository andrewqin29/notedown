local Context = require('notedown.request.context')
local Marks = require('notedown.lib.marks')
local ts = require('notedown.core.ts')

---@class notedown.handler.Markdown: notedown.Handler
local M = {}

---@param ctx notedown.handler.Context
---@return notedown.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('markdown', [[
        [
            (thematic_break)
            (minus_metadata)
            (plus_metadata)
        ] @dash

        (document) @document

        (atx_heading) @heading

        (list_item) @list

        (section (paragraph) @paragraph)

        (block_quote) @quote

        (pipe_table) @table
    ]])
    ---@type table<string, notedown.Render>
    local renders = {
        dash = require('notedown.render.markdown.dash'),
        document = require('notedown.render.markdown.document'),
        heading = require('notedown.render.markdown.heading'),
        list = require('notedown.render.markdown.list'),
        paragraph = require('notedown.render.markdown.paragraph'),
        quote = require('notedown.render.markdown.quote'),
        table = require('notedown.render.markdown.table'),
    }
    local context = Context.get(ctx.buf)
    local marks = Marks.new(context, false)
    context.view:nodes(ctx.root, query, function(capture, node)
        local render = renders[capture]
        assert(render, ('unhandled markdown capture: %s'):format(capture))
        render:execute(context, marks, node)
    end)
    -- the note format's blocks, typography and justification (notes/blocks.lua)
    local result = marks:get()
    if require('notedown.state').notes then
        vim.list_extend(result, require('notedown.notes.blocks').parse(ctx))
    end
    return result
end

return M
