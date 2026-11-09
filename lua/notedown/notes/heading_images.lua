-- Bigger # and ## headings in markdown. A terminal draws all text at one size,
-- so these headings are drawn as images instead (with ImageMagick, in the
-- terminal's font, bold, in the heading's color) and shown by snacks.nvim in
-- place of the line, like typeset math. # is 1.5x the size of normal text and
-- ## is 1.25x; both take two rows. Other headings stay text. The heading shows
-- as text while the cursor is on it.
--
-- notes/blocks.lua adds these to what snacks finds (M.matches), and
-- notes/init.lua has snacks hide the line under them.

local M = {}

-- Size relative to normal text, by number of #s.
M.scale = { [1] = 1.5, [2] = 1.25 }
M.rows = 2

M.font = vim.trim(vim.fn.system({ "fc-match", "-f", "%{file}", "JetBrainsMono Nerd Font:bold" }))

-- JetBrains Mono's characters are 0.6 of the font size wide, so the size
-- normal text is drawn at follows from the terminal's cell width.
local GLYPH_WIDTH = 0.6

local function color(level)
  local hl = vim.api.nvim_get_hl(0, { name = "NotedownH" .. level, link = false })
  return hl.fg and ("#%06x"):format(hl.fg) or "#ffffff"
end

-- The heading as plain text: emphasis and code marks dropped, punctuation
-- made typographic (notes/typography.lua).
local function plain(text)
  text = text:gsub("%s+#+%s*$", "") -- closing #s
  text = text:gsub("`", ""):gsub("%*%*", ""):gsub("__", "")
  text = text:gsub("%f[%w%*]%*(.-)%*", "%1"):gsub("%[(.-)%]%b()", "%1")
  text = require("notedown.notes.typography").smarten(text)
  return vim.trim(text)
end

M.plain = plain

local function magick(args)
  local result = vim.system(vim.list_extend({ "magick" }, args), { text = true }):wait()
  return result.code == 0 and vim.trim(result.stdout or "") or nil
end

-- Words of text in lines of at most width characters.
local function wrap(text, width)
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    if line ~= "" and vim.fn.strchars(line .. " " .. word) > width then
      lines[#lines + 1] = line
      line = word
    else
      line = line == "" and word or line .. " " .. word
    end
  end
  lines[#lines + 1] = line
  return table.concat(lines, "\n")
end

-- A PNG of the heading, made once per text, level, color, cell size and the
-- number of columns it has to fit in. A heading longer than that wraps onto
-- more lines, taking two more rows each, rather than being drawn smaller.
local function image(text, level, cols)
  local term = Snacks.image.terminal.size()
  local cell_w, cell_h = term.cell_width, term.cell_height
  local px = math.floor(cell_w / GLYPH_WIDTH * M.scale[level] + 0.5)
  text = wrap(text, math.max(1, math.floor(cols * cell_w / (px * GLYPH_WIDTH))))
  local fill = color(level)
  local key = table.concat({ text, level, fill, cell_w, cell_h, term.scale, M.font }, "\0")
  local root = Snacks.image.config.cache
  local file = root .. "/heading-" .. vim.fn.sha256(key):sub(1, 12) .. ".png"
  if vim.fn.filereadable(file) == 1 then return file end
  vim.fn.mkdir(root, "p")

  -- label: reads a file for text starting with @, and expands % escapes.
  local label = "label:" .. text:gsub("%%", "%%%%"):gsub("^@", "\\@")
  local draw = { "-background", "none", "-fill", fill, "-font", M.font, "-pointsize", px, label }
  local measured = magick(vim.list_extend(vim.deepcopy(draw), { "-format", "%w %h", "info:" }))
  local width, height = (measured or ""):match("^(%d+) (%d+)$")
  if not width then return nil end

  -- Exactly whole cells, so snacks shows it at its own size: as wide as the
  -- text and at least M.rows tall. Snacks turns an image's size into screen
  -- pixels as size / density * 96 * scale, taking the density as per inch, so
  -- a density of 96 * scale keeps it as it is. It reads the number ImageMagick
  -- reports, which for a PNG is per centimetre, so it's written per centimetre.
  local rows = math.max(M.rows, math.ceil(tonumber(height) / cell_h))
  local size = ("%dx%d"):format(math.ceil(width / cell_w) * cell_w, math.floor(rows * cell_h))
  local ok = magick(vim.list_extend(draw, {
    "-gravity", "west", "-extent", size,
    "-units", "PixelsPerCentimeter", "-density", tostring(96 * term.scale), file,
  }))
  return ok and file or nil
end

-- Snacks matches for the # and ## headings between rows from and to (1-based,
-- either nil for all), outside fenced code blocks and rows in skip.
function M.matches(buf, lines, from, to, skip)
  if M.font == "" then return {} end
  -- The columns a heading has to fit in: the text area of the buffer's window.
  local win = require("notedown.notes.window")(buf)
  local info = win and vim.fn.getwininfo(win)[1]
  local cols = info and (info.width - info.textoff - 1) or 80
  local found, fence = {}, nil
  for i, line in ipairs(lines) do
    local marker = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if marker then
      if not fence then
        fence = marker
      elseif marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        fence = nil
      end
    elseif not fence and not (skip and skip[i]) and (not from or (i >= from and i <= to)) then
      local hashes, text = line:match("^(#+)%s+(.-)%s*$")
      local level = hashes and #hashes
      text = text and plain(text)
      local src = level and M.scale[level] and text ~= "" and image(text, level, cols)
      if src then
        found[#found + 1] = {
          id = "heading-" .. i,
          lang = "markdown",
          type = "heading",
          src = src,
          pos = { i, 0 },
          range = { i, 0, i, #line },
        }
      end
    end
  end
  return found
end

-- snacks shrinks images wider than 80 columns (its doc.max_width), which
-- would draw long headings smaller than the rest. Headings already fit the
-- window, so let them be as wide as it. Called by notes/blocks.lua.
function M.patch_placement(placement)
  local new = placement.new
  placement.new = function(buf, src, opts)
    if opts and opts.type == "heading" then
      local win = require("notedown.notes.window")(buf)
      local info = win and vim.fn.getwininfo(win)[1]
      opts.max_width = info and (info.width - info.textoff) or opts.max_width
    end
    return new(buf, src, opts)
  end
end

return M
