-- notedown's highlight groups. Most link to the colorscheme's groups and can
-- be set in it instead (they're defaults); the rest are worked out from it.
-- All are set again when the colorscheme changes.

local M = {}

local LINKS = {
  -- headings: their color (heading images, the breadcrumb and contents), and
  -- the bar behind ### to ######
  NotedownH1 = "@markup.heading.1.markdown",
  NotedownH2 = "@markup.heading.2.markdown",
  NotedownH3 = "@markup.heading.3.markdown",
  NotedownH4 = "@markup.heading.4.markdown",
  NotedownH5 = "@markup.heading.5.markdown",
  NotedownH6 = "@markup.heading.6.markdown",
  NotedownH3Bg = "DiffChange",
  NotedownH4Bg = "DiffDelete",
  NotedownH5Bg = "Visual",
  NotedownH6Bg = "CursorColumn",
  -- >> code blocks and `code`, and a code block's label
  NotedownCode = "ColorColumn",
  NotedownCodeLabel = "@label",
  NotedownBullet = "Normal",
  NotedownUnchecked = "@markup.list.unchecked",
  NotedownChecked = "@markup.list.checked",
  NotedownQuote = "@markup.quote",
  NotedownDash = "LineNr",
  -- a footnote's number in the text
  NotedownFootnoteRef = "@markup.link",
  -- what you type, in the help popup
  NotedownHelpKey = "@label",
}

-- How much of a callout's color is mixed into the editor's background for
-- its tint.
M.TINT = 0.12

local function blend(fg, bg, amount)
  local function channel(shift)
    local a, b = bit.band(bit.rshift(fg, shift), 0xff), bit.band(bit.rshift(bg, shift), 0xff)
    return bit.lshift(math.floor(b + (a - b) * amount + 0.5), shift)
  end
  return bit.bor(channel(16), channel(8), channel(0))
end

local function get(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
end

function M.define()
  for name, link in pairs(LINKS) do
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end

  -- Callouts (blocks.lua): the tint behind the block, and the bar and title
  -- in the callout's color on it.
  local normal = get("Normal")
  for _, kind in pairs(require("notedown.blocks").kinds) do
    if kind.icon then
      local fg = get(kind.color).fg or 0xffffff
      local tint = blend(fg, normal.bg or 0, M.TINT)
      vim.api.nvim_set_hl(0, kind.bg, { bg = tint })
      vim.api.nvim_set_hl(0, kind.fg, { fg = fg, bg = tint })
    end
  end

  -- ==highlights==, bright yellow; --strikethroughs--; picture captions, dim and italic.
  vim.api.nvim_set_hl(0, "NotedownHighlight", { bg = "#ffd700", fg = "#000000" })
  vim.api.nvim_set_hl(0, "NotedownStrikethrough", { strikethrough = true })
  -- Footnotes at the end of a note: the text's color, halfway to the
  -- background.
  vim.api.nvim_set_hl(0, "NotedownFootnote", { fg = blend(normal.fg or 0xffffff, normal.bg or 0, 0.5) })
  vim.api.nvim_set_hl(0, "NotedownImageCaption", { fg = get("Comment").fg, italic = true })
  -- >> boxed: white text, the border in the editor's text color.
  vim.api.nvim_set_hl(0, "NotedownBoxText", { fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "NotedownBoxBorder", { fg = normal.fg })
  -- Typeset math is drawn in this color.
  vim.api.nvim_set_hl(0, "SnacksImageMath", { fg = "#ffffff" })

  -- Markdown's own inline text: `code` on the code background, and emphasis
  -- bold and italic whatever the colorscheme does elsewhere.
  vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { link = "NotedownCode" })
  vim.api.nvim_set_hl(0, "@markup.strong.markdown_inline", { bold = true })
  vim.api.nvim_set_hl(0, "@markup.italic.markdown_inline", { italic = true })
end

function M.setup()
  M.define()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("notedown.highlights", { clear = true }),
    callback = M.define,
  })
end

return M
