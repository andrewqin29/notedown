-- notedown's help (:help or F1 in a markdown file): a popup in the middle of
-- the screen with what to write and the commands and keys. j/k scroll when it's
-- taller than the screen; q or Esc closes it. :help with a topic after it is
-- nvim's own help, as everywhere else.

local M = {}

local ns = vim.api.nvim_create_namespace("notedown.help")

-- Sections of { what you type, what it does }.
local SECTIONS = {
  {
    title = "Write",
    { ">> note … <<", "a callout (also tip, important, warning, caution)" },
    { ">> python … <<", "highlighted code (also c, cpp, java, rust, ocaml)" },
    { ">> latex … <<", "typeset formulas, one per line" },
    { ">> mermaid … <<", "a diagram" },
    { ">> boxed … <<", "its lines in a box" },
    { "# ##", "large headings, drawn as images" },
    { "### to ######", "headings on a colored bar" },
    { "- 1. > ---", "bullets, numbers, quote bars, a line" },
    { "[x] [-]", "a checked and an unchecked box (also after -)" },
    { "*bold* _italic_", "bold, italic" },
    { "==highlight== --struck--", "highlighted, struck through" },
    { "![caption](picture.png)", "the picture, centered, with its caption" },
    { "[^label]", "a numbered footnote, its stub added at the end" },
    { [[-- "quotes" 1/2 (c) 2026]], "— “quotes” ½ ©" },
  },
  {
    title = "Commands",
    { ":toc  gO", "table of contents: Enter jumps, q closes" },
    { ":read", "reading mode: Esc leaves" },
    { ":raw", "reading mode, nothing rendered" },
    { ":Notedown", "rendering off and on" },
    { ":help  F1", "this help; :help topic for nvim's" },
  },
}

-- The popup's lines, and the highlights on them as { row, from, to, group }.
local function contents()
  local key_width = 0
  for _, section in ipairs(SECTIONS) do
    for _, entry in ipairs(section) do key_width = math.max(key_width, vim.api.nvim_strwidth(entry[1])) end
  end
  local lines, hls = {}, {}
  for i, section in ipairs(SECTIONS) do
    if i > 1 then lines[#lines + 1] = "" end
    lines[#lines + 1] = " " .. section.title
    hls[#hls + 1] = { #lines - 1, 1, #lines[#lines], "NotedownH3" }
    for _, entry in ipairs(section) do
      local key = entry[1] .. (" "):rep(key_width - vim.api.nvim_strwidth(entry[1]))
      lines[#lines + 1] = "   " .. key .. "   " .. entry[2] .. " "
      hls[#hls + 1] = { #lines - 1, 3, 3 + #entry[1], "NotedownHelpKey" }
    end
  end
  return lines, hls
end

function M.open()
  local lines, hls = contents()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(buf, ns, hl[1], hl[2], { end_col = hl[3], hl_group = hl[4] })
  end
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "notedown_help"

  local widest = 0
  for _, line in ipairs(lines) do widest = math.max(widest, vim.api.nvim_strwidth(line)) end
  -- (the screen less the command line and the popup's border)
  local width = math.min(widest, vim.o.columns - 4)
  local height = math.min(#lines, vim.o.lines - vim.o.cmdheight - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.floor((vim.o.lines - vim.o.cmdheight - height - 2) / 2),
    col = math.floor((vim.o.columns - width - 2) / 2),
    width = math.max(width, 1),
    height = math.max(height, 1),
    border = "rounded",
    title = " notedown ",
    title_pos = "center",
    style = "minimal",
  })
  vim.wo[win].wrap = false

  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  for _, key in ipairs({ "q", "<Esc>", "<F1>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, nowait = true })
  end
  vim.api.nvim_create_autocmd("WinLeave", { buffer = buf, once = true, callback = close })
end

return M
