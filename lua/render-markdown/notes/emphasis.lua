-- Emphasis in markdown, my way: *bold* and _italic_, while **x** and __x__
-- are plain text with their marks showing. Markdown itself reads * and _ both
-- as italic and ** and __ both as bold, so this replaces the highlight query
-- for markdown's inline text (from nvim-treesitter) with one whose rules for
-- emphasis are changed. The rest of the query stays as it is.

local M = {}

local RULES = [[
; *x* bold, _x_ italic, by the mark the text starts with.
((emphasis) @markup.strong (#lua-match? @markup.strong "^%*"))
((emphasis) @markup.italic (#lua-match? @markup.italic "^_"))

; Hide the marks of those, but not of **x** and __x__.
(emphasis (emphasis_delimiter) @conceal (#set! conceal ""))
((code_span_delimiter) @conceal (#set! conceal ""))
]]

function M.setup()
  local files = vim.treesitter.query.get_files("markdown_inline", "highlights")
  if #files == 0 then return end
  local query = table.concat(vim.fn.readfile(files[1]), "\n")

  -- Drop the original emphasis rules and the conceal rule they share with
  -- code spans (put back above, without emphasis in **x** and __x__).
  local before = query
  query = query:gsub("%(emphasis%) @markup%.italic%s*\n", "")
  query = query:gsub("%(strong_emphasis%) @markup%.strong%s*\n", "")
  query = query:gsub("%(%[%s*%(code_span_delimiter%)%s*%(emphasis_delimiter%)%s*%] @conceal%s*%(#set! conceal \"\"%)%)", "")
  if query == before then return end -- the query changed upstream; leave it

  vim.treesitter.query.set("markdown_inline", "highlights", query .. "\n" .. RULES)
end

return M
