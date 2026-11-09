-- Markdown syntax this note format replaces does nothing, so notes can't mix
-- two ways of writing the same thing:
--
--   ```lang fences  (>> python and the rest)  shown as typed: no colors, the
--   indented code    fence lines not hidden; nvim's markdown parser still
--                    reads what's inside as code, so nothing renders there
--   Setext headings  (# and ##)  Title over === or --- is a paragraph
--
-- Also elsewhere: > [!NOTE] callouts (notes/init.lua), ```math,
-- $$...$$ and ```mermaid images (notes/blocks.lua), **x** and __x__
-- (notes/emphasis.lua).
--
-- This replaces the highlight and injection queries for markdown (from
-- nvim-treesitter) with ones whose rules for those are taken out. If one of
-- them changed upstream so a rule can't be found, that query is left as it is.

local M = {}

local function edit(lang, name, removals)
  local files = vim.treesitter.query.get_files(lang, name)
  if #files == 0 then return end
  local query = table.concat(vim.fn.readfile(files[1]), "\n")
  for _, pattern in ipairs(removals) do
    local new, count = query:gsub(pattern, "")
    if count == 0 then return end
    query = new
  end
  vim.treesitter.query.set(lang, name, query)
end

function M.setup()
  edit("markdown", "highlights", {
    -- Setext headings.
    "%(setext_heading%s*%(paragraph%) @markup%.heading%.1%s*%(setext_h1_underline%) @markup%.heading%.1%)",
    "%(setext_heading%s*%(paragraph%) @markup%.heading%.2%s*%(setext_h2_underline%) @markup%.heading%.2%)",
    -- Code blocks: their color, and hiding the fence and language lines.
    "%(indented_code_block%) @markup%.raw%.block",
    "%(%(fenced_code_block%) @markup%.raw%.block%s*%(#set! priority 90%)%)",
    "%(fenced_code_block%s*%(fenced_code_block_delimiter%) @markup%.raw%.block%s*%(#set! conceal \"\"%)%s*%(#set! conceal_lines \"\"%)%)",
    "%(fenced_code_block%s*%(info_string%s*%(language%) @label%s*%(#set! conceal \"\"%)%s*%(#set! conceal_lines \"\"%)%)%)",
  })
  edit("markdown", "injections", {
    -- Code in a fence highlighted as its language.
    "%(fenced_code_block%s*%(info_string%s*%(language%) @injection%.language%)%s*%(code_fence_content%) @injection%.content%)",
  })
end

return M
