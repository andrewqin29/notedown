-- nvim-treesitter's markdown queries, changed for the format. Markdown
-- syntax the format replaces does nothing, so notes can't mix two ways of
-- writing the same thing:
--
--   ```lang fences   (>> python and the rest)  shown as typed: no colors, the
--   indented code     fence lines not hidden; nvim's markdown parser still
--                     reads what's inside as code, so nothing renders there
--   setext headings  (# and ##)  Title over === or --- is a paragraph
--   **x** and __x__  plain text, their marks showing
--   ~~x~~            (--x--)  plain text too
--
-- and emphasis is *bold* and _italic_ (markdown reads * and _ both as italic,
-- and ** and __ both as bold).
--
-- Also elsewhere: > [!NOTE] callouts are plain quotes (markdown.lua draws no
-- callouts), and ```math, $$...$$ and ```mermaid show no image (images.lua).
--
-- A rule that can't be found (the query changed upstream) leaves that query
-- as it is.

local M = {}

-- The query with each removal taken out, or nil if one isn't there.
local function without(lang, name, removals)
  local files = vim.treesitter.query.get_files(lang, name)
  if #files == 0 then return nil end
  local query = table.concat(vim.fn.readfile(files[1]), "\n")
  for _, pattern in ipairs(removals) do
    local new, count = query:gsub(pattern, "")
    if count == 0 then return nil end
    query = new
  end
  return query
end

local function set(lang, name, query)
  if query then vim.treesitter.query.set(lang, name, query) end
end

local EMPHASIS = [[
; *x* bold, _x_ italic, by the mark the text starts with.
((emphasis) @markup.strong (#lua-match? @markup.strong "^%*"))
((emphasis) @markup.italic (#lua-match? @markup.italic "^_"))

; Hide the marks of those, but not of **x** and __x__.
(emphasis (emphasis_delimiter) @conceal (#set! conceal ""))
((code_span_delimiter) @conceal (#set! conceal ""))
]]

function M.setup()
  set("markdown", "highlights", without("markdown", "highlights", {
    -- Setext headings.
    "%(setext_heading%s*%(paragraph%) @markup%.heading%.1%s*%(setext_h1_underline%) @markup%.heading%.1%)",
    "%(setext_heading%s*%(paragraph%) @markup%.heading%.2%s*%(setext_h2_underline%) @markup%.heading%.2%)",
    -- Code blocks: their color, and hiding the fence and language lines.
    "%(indented_code_block%) @markup%.raw%.block",
    "%(%(fenced_code_block%) @markup%.raw%.block%s*%(#set! priority 90%)%)",
    "%(fenced_code_block%s*%(fenced_code_block_delimiter%) @markup%.raw%.block%s*%(#set! conceal \"\"%)%s*%(#set! conceal_lines \"\"%)%)",
    "%(fenced_code_block%s*%(info_string%s*%(language%) @label%s*%(#set! conceal \"\"%)%s*%(#set! conceal_lines \"\"%)%)%)",
  }))
  set("markdown", "injections", without("markdown", "injections", {
    -- Code in a fence highlighted as its language.
    "%(fenced_code_block%s*%(info_string%s*%(language%) @injection%.language%)%s*%(code_fence_content%) @injection%.content%)",
  }))
  -- The emphasis rules, and the conceal rule they share with code spans (put
  -- back in EMPHASIS, without emphasis in **x** and __x__).
  local inline = without("markdown_inline", "highlights", {
    "%(emphasis%) @markup%.italic%s*\n",
    "%(strong_emphasis%) @markup%.strong%s*\n",
    "%(strikethrough%) @markup%.strikethrough%s*\n",
    "%(%[%s*%(code_span_delimiter%)%s*%(emphasis_delimiter%)%s*%] @conceal%s*%(#set! conceal \"\"%)%)",
  })
  set("markdown_inline", "highlights", inline and (inline .. "\n" .. EMPHASIS))
end

return M
