-- The note format this fork renders, on top of render-markdown's own markdown
-- rendering. Its parts:
--
--   blocks          >> note / tip / important / warning / caution, >> python
--                   and other code, >> latex, >> mermaid, >> boxed (blocks.lua)
--   justify         justified paragraphs, lines broken for the whole paragraph
--   typography      dashes, curly quotes, fractions, © ® ™
--   heading_images  # and ## drawn larger, as images
--   emphasis        *bold* and _italic_; **x** and __x__ are plain text
--   legacy          ``` fences, indented code and setext headings are plain text
--   breadcrumb      the heading path at the top of markdown windows
--   toc             gO or :toc, a table of contents popup
--   reading         :read, reading mode
--
-- Images (typeset LaTeX, mermaid diagrams, # and ## headings, pictures) need
-- snacks.nvim with its image module enabled, in a terminal with kitty's
-- graphics protocol (Ghostty, kitty). Mermaid needs mermaid-cli (mmdc).

local M = {}

-- render-markdown settings the format uses, under the user's own.
M.defaults = {
  -- The quote bar on every wrapped line, not only the first. Wrapped quote
  -- lines start two columns in, under the text (blocks.lua, list_pattern).
  quote = { repeat_linebreak = true },
  -- No icons in front of headings or in the sign column, and no colored bar
  -- behind # and ## (drawn as images, heading_images.lua).
  heading = {
    icons = { "" },
    position = "inline",
    sign = false,
    backgrounds = { "Normal", "Normal", "RenderMarkdownH3Bg", "RenderMarkdownH4Bg",
      "RenderMarkdownH5Bg", "RenderMarkdownH6Bg" },
  },
  -- ==highlighted== text, bright yellow (NotesHighlight, blocks.lua).
  inline_highlight = { highlight = "NotesHighlight" },
  -- Lists start one level in from the text around them. Bullets by level:
  -- medium dots (Nerd Font octicons dot-fill and dot), then medium squares
  -- (Nerd Font Material Design icons), each one column wide.
  bullet = { left_pad = 2, icons = { "\u{f444}", "\u{f4c3}", "\u{f0a13}", "\u{f0a14}" } },
  checkbox = { left_pad = 2 },
  -- Only while rendered: raw view wraps as usual.
  win_options = {
    -- Wrap between words, not mid-word.
    linebreak = { default = vim.o.linebreak, rendered = true },
    -- A wrapped list item or quote continues under its text, not its bullet
    -- or bar; other lines continue at the left edge. How far in is set by
    -- 'formatlistpat' (blocks.lua, list_pattern).
    breakindent = { default = vim.o.breakindent, rendered = true },
    breakindentopt = { default = vim.o.breakindentopt, rendered = "list:-1" },
  },
}

-- The plugin's own directory, for its assets.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h:h")

local function highlights()
  require("render-markdown.notes.blocks").define_highlights()
  -- Emphasis is bold and italic in notes whatever the colorscheme does
  -- elsewhere: these are only for markdown's inline text.
  vim.api.nvim_set_hl(0, "@markup.strong.markdown_inline", { bold = true })
  vim.api.nvim_set_hl(0, "@markup.italic.markdown_inline", { italic = true })
  -- Typeset math is drawn in this color.
  vim.api.nvim_set_hl(0, "SnacksImageMath", { fg = "#ffffff" })
end

-- snacks.nvim's image settings for notes, and the image parts of blocks.lua.
local function snacks()
  local ok, image = pcall(function() return Snacks.image end)
  if not ok or not image or not image.config then return end
  local config = image.config
  -- LaTeX's normal text size (12pt).
  config.math = config.math or {}
  config.math.latex = config.math.latex or {}
  config.math.latex.font_size = "normalsize"
  -- Mermaid diagrams with mermaid-cli, using the installed Chrome and colors
  -- to match (assets/mermaid).
  config.convert = config.convert or {}
  config.convert.mermaid = function()
    local dir = root .. "/assets/mermaid/"
    return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-s", "{scale}",
      "-p", dir .. "puppeteer.json", "-c", dir .. "config.json" }
  end
  -- Hide the text under typeset math, big headings, images (their ![](...)
  -- line) and diagrams. The text shows while the cursor is on it.
  config.doc = config.doc or {}
  config.doc.conceal = function(_, type)
    return type == "math" or type == "heading" or type == "image" or type == "chart"
  end
  require("render-markdown.notes.blocks").setup_snacks()
end

-- What each markdown buffer gets.
local function markdown_buffer(buf)
  -- How far in wrapped lines continue (blocks.lua, list_pattern).
  vim.bo[buf].formatlistpat = require("render-markdown.notes.blocks").list_pattern
  -- The table of contents popup, in place of nvim's own gO (location list).
  vim.keymap.set("n", "gO", function() require("render-markdown.notes.toc").open() end,
    { buffer = buf, desc = "Table of contents" })
end

local done = false

function M.setup()
  if done then return end
  done = true

  local group = vim.api.nvim_create_augroup("render-markdown.notes", { clear = true })
  highlights()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = highlights })

  require("render-markdown.notes.emphasis").setup()
  require("render-markdown.notes.legacy").setup()
  snacks()

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "markdown",
    callback = function(ev) markdown_buffer(ev.buf) end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "markdown" then
      markdown_buffer(buf)
    end
  end

  require("render-markdown.notes.breadcrumb").setup()
  vim.api.nvim_create_user_command("Toc", function() require("render-markdown.notes.toc").open() end,
    { desc = "Table of contents of the markdown note" })
  require("render-markdown.notes.reading").setup()
end

return M
