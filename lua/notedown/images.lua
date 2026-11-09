-- Images in notes, shown by snacks.nvim's image module in a terminal with
-- kitty's graphics protocol (Ghostty, kitty):
--
--   >> latex     the formulas typeset with pdflatex, one per line, centered
--   >> mermaid   the diagram, made by mermaid-cli (mmdc) in colors to match
--                (assets/mermaid)
--   # and ##     larger headings (heading_images.lua)
--   ![alt](...)  the picture, centered, with its alt text as a caption
--   $x$          inline math, typeset in the line
--
-- Each hides the text under it, which shows while the cursor is on it: a
-- picture then shows below its line, the others not at all. A heading keeps
-- its text while its line is being edited, and becomes an image again once
-- the cursor leaves it. Where images can't be shown, the text shows as typed.
--
-- snacks finds images itself with tree-sitter, which can't see >> blocks, and
-- doesn't center, caption or resize them, so this wraps parts of it (M.setup).

local M = {}

-- Largest size of a picture or diagram: rows tall, and share of the window's
-- width. Each keeps its shape.
M.ROWS = 20
M.WIDTH = 0.8

-- The plugin's own directory, for its assets.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")

local function window_width(buf)
  local win = require("notedown.window")(buf)
  local info = win and vim.fn.getwininfo(win)[1]
  return info and (info.width - info.textoff)
end

-- The block's LaTeX as one display: each line its own centered formula. A
-- block that already starts with \begin (aligned, cases, ...) is typeset as
-- it is.
local function block_latex(lines, block)
  local body = {}
  for row = block.first + 1, block.last - 1 do
    local tex = vim.trim(lines[row + 1])
    if tex ~= "" then body[#body + 1] = tex end
  end
  if #body == 0 then return nil end
  if body[1]:find("^\\begin") then return table.concat(body, "\n") end
  return "\\begin{gather*}\n" .. table.concat(body, " \\\\\n") .. "\n\\end{gather*}"
end

-- A file in snacks' cache holding content, named by its hash.
local function cached(content, ext)
  local dir = Snacks.image.config.cache
  vim.fn.mkdir(dir, "p")
  local src = dir .. "/" .. vim.fn.sha256(content):sub(1, 8) .. "-content." .. ext
  if vim.fn.filereadable(src) == 0 then
    local file = assert(io.open(src, "w"))
    file:write(content)
    file:close()
  end
  return src
end

-- snacks matches for the note's >> latex and >> mermaid blocks between rows
-- from and to (1-based, nil for all), built the way snacks builds a ```math
-- block.
local function block_matches(buf, scan, from, to)
  local lines, doc, found = scan.lines, require("snacks.image.doc"), {}
  for _, block in ipairs(scan.blocks) do
    local visible = not from or (block.last + 1 >= from and block.first + 1 <= to)
    local range = { block.first + 1, 0, block.last + 1, #lines[block.last + 1] }
    local tex = block.kind.math and visible and block_latex(lines, block)
    if tex then
      local img = {
        id = "latex-block-" .. block.first,
        lang = "markdown",
        type = "math",
        ext = "math.tex",
        content = tex,
        pos = { block.first + 1, 0 },
        range = range,
      }
      doc.transforms.latex(img, { buf = buf })
      img.src = cached(img.content, "math.tex")
      found[#found + 1] = img
    end
    if block.kind.chart and visible and block.last > block.first + 1 then
      found[#found + 1] = {
        id = "mermaid-block-" .. block.first,
        lang = "markdown",
        type = "chart",
        ext = "chart.mmd",
        src = cached(table.concat(vim.list_slice(lines, block.first + 2, block.last), "\n"), "chart.mmd"),
        pos = { block.first + 1, 0 },
        range = range,
      }
    end
  end
  return found
end

-- Of what snacks finds itself, only pictures and inline $math$: ```math,
-- $$...$$ and ```mermaid aren't part of the format (queries.lua). By now a
-- formula's content is a whole LaTeX document, so this looks at the note's
-- own text where it is.
local function own_matches(buf, matches)
  return vim.tbl_filter(function(m)
    if m.type == "image" then return true end
    if m.type ~= "math" or not m.range then return false end
    local r = m.range
    local ok, text = pcall(vim.api.nvim_buf_get_text, buf, r[1] - 1, r[2], r[3] - 1, r[4], {})
    local source = ok and table.concat(text, "\n") or ""
    return source:find("^%$") ~= nil and source:find("^%$%$") == nil
  end, matches)
end

-- A latex or mermaid block's >> line stays under its image, which is
-- centered, so it doesn't cover the >>: cover it with blanks while the image
-- shows.
local marker_ns = vim.api.nvim_create_namespace("notedown.images.marker")
local markers = {} -- extmark id by placement id

local function cover_marker(placement, closing)
  local range, id = placement.opts.range, markers[placement.id]
  local line = range and vim.api.nvim_buf_get_lines(placement.buf, range[1] - 1, range[1], false)[1]
  local typed = placement.opts.type == "math" or placement.opts.type == "chart"
  if not closing and not placement.hidden and typed and line and line:match("^>>") then
    markers[placement.id] = vim.api.nvim_buf_set_extmark(placement.buf, marker_ns, range[1] - 1, 0, {
      id = id,
      virt_text = { { "  " } },
      virt_text_pos = "overlay",
      priority = 10002,
    })
  elseif id then
    pcall(vim.api.nvim_buf_del_extmark, placement.buf, marker_ns, id)
    markers[placement.id] = nil
  end
end

-- The window column that centers an image, or nil to leave it: for one with
-- text before or after it on its lines, or when no window shows it.
local function centered_offset(placement, extmarks)
  local range = placement.opts.range
  if not range then return nil end
  local lines = vim.api.nvim_buf_get_lines(placement.buf, range[1] - 1, range[3], false)
  if #lines == 0 or lines[1]:sub(1, range[2]):find("%S") or lines[#lines]:sub(range[4] + 1):find("%S") then
    return nil
  end

  -- The image's width in cells: each cell of a row is a placeholder character
  -- plus two marks giving its position.
  local width = 0
  for _, extmark in ipairs(extmarks) do
    local row = extmark.virt_text and extmark.virt_text[1] and extmark.virt_text[1][1]
    if not row and extmark.virt_lines and extmark.virt_lines[1] then
      local last = extmark.virt_lines[1][#extmark.virt_lines[1]]
      row = last and last[1]
    end
    if row then width = math.max(width, math.floor(vim.fn.strchars(row) / 3)) end
  end
  local text_width = window_width(placement.buf)
  if width == 0 or not text_width then return nil end
  return math.max(0, math.floor((text_width - width) / 2))
end

-- A picture's caption: the alt text of the ![alt](...) its line holds.
local function caption(placement)
  local range = placement.opts.range
  local line = range and vim.api.nvim_buf_get_lines(placement.buf, range[1] - 1, range[1], false)[1]
  local alt = line and line:match("!%[(.-)%]")
  return alt and vim.trim(alt) ~= "" and vim.trim(alt) or nil
end

-- A placement's image rows as virtual lines below its last line, for a
-- picture on the cursor's line: the ![...](...) shows as typed for editing,
-- and the picture stays in view under it. (snacks hides the picture there,
-- leaving blank rows.)
local PLACEHOLDER = "\u{10EEEE}" -- each cell of an image is one
local function below(placement, extmarks)
  local rows = {}
  for _, e in ipairs(extmarks) do
    if e.virt_text and e.virt_text[1] and e.virt_text[1][1]:find(PLACEHOLDER, 1, true) then
      rows[#rows + 1] = { { (" "):rep(e.virt_text_win_col or 0) }, e.virt_text[1] }
    end
    vim.list_extend(rows, e.virt_lines or {})
  end
  local range = placement.opts.range
  return { { row = range[3] - 1, col = 0, virt_lines = rows, virt_text_hide = false, priority = 10001 } }
end

-- Send every image snacks has sent to the terminal again, and place each of
-- its placements again. snacks keeps its images in a table private to its
-- image module, reached here through the function that adds to it.
local function resend()
  local image = require("snacks.image.image")
  local images
  for i = 1, math.huge do
    local name, value = debug.getupvalue(image.new, i)
    if not name then break end
    if name == "images" then
      images = value
      break
    end
  end
  for _, img in pairs(images or {}) do
    if img.sent then
      img.sent = false
      for _, placement in pairs(img.placements) do
        placement._state = nil -- otherwise an unchanged placement isn't redone
        placement:update()
      end
    end
  end
end

-- snacks' settings for notes.
local function configure(config)
  -- LaTeX's normal text size (12pt).
  config.math = config.math or {}
  config.math.latex = config.math.latex or {}
  config.math.latex.font_size = "normalsize"
  -- Mermaid diagrams with mermaid-cli, using the installed Chrome and colors
  -- to match.
  config.convert = config.convert or {}
  config.convert.mermaid = function()
    local dir = root .. "/assets/mermaid/"
    return { "-i", "{src}", "-o", "{file}", "-b", "transparent", "-s", "{scale}",
      "-p", dir .. "puppeteer.json", "-c", dir .. "config.json" }
  end
  -- Hide the text under typeset math, headings, pictures (their ![](...)
  -- line) and diagrams.
  config.doc = config.doc or {}
  config.doc.conceal = function(_, type)
    return type == "math" or type == "heading" or type == "image" or type == "chart"
  end
end

function M.setup()
  local ok, image = pcall(function() return Snacks.image end)
  if not ok or not image or not image.config then return end
  configure(image.config)

  -- If anything asked snacks for the terminal's capabilities before the
  -- terminal answered, snacks remembers an answer without Ghostty in it, and
  -- shows no inline images all session. Forget it once the answer is in,
  -- before snacks sets up images in any buffer (which waits for the same
  -- answer).
  local terminal = require("snacks.image.terminal")
  terminal.detect(function() terminal._env = nil end)

  -- Ghostty can lose images when its window is resized (another pane opening
  -- beside it, say), but snacks sends each image only once, so images placed
  -- again after a resize point at nothing and don't show. Send every image
  -- again once a resize settles (after snacks' own update, 100 ms after it).
  local resend_later = Snacks.util.debounce(resend, { ms = 300 })
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("notedown.images", { clear = true }),
    callback = function() resend_later() end,
  })

  -- snacks' image updater of each buffer, to update it when notedown needs
  -- (it updates itself only when the text changes or the window scrolls).
  local updaters = {}
  local inline = require("snacks.image.inline")
  local inline_new = inline.new
  inline.new = function(buf)
    local updater = inline_new(buf)
    updaters[buf] = updater
    return updater
  end

  -- The row (1-based) of a heading left as text by buffer, while the cursor
  -- is on it: snacks finds images again after every change, and each version
  -- of a heading being edited would be a new image, drawn over the line.
  local editing = {}
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
    group = vim.api.nvim_create_augroup("notedown.images.editing", { clear = true }),
    callback = function(ev)
      local row = editing[ev.buf]
      if not row then return end
      if ev.event == "BufLeave" or vim.api.nvim_win_get_cursor(0)[1] ~= row then
        editing[ev.buf] = nil
        if updaters[ev.buf] then updaters[ev.buf]:update() end
      end
    end,
  })

  -- What snacks finds in a note: its pictures and inline math, the >> latex
  -- and >> mermaid blocks, and the # and ## headings outside fences and >>
  -- blocks, but not the one the cursor is on.
  local doc = require("snacks.image.doc")
  local find = doc.find
  doc.find = function(buf, cb, opts)
    find(buf, function(matches)
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "markdown" then
        local scan = require("notedown.blocks").scan(buf)
        local from, to = opts and opts.from, opts and opts.to
        matches = own_matches(buf, matches)
        vim.list_extend(matches, block_matches(buf, scan, from, to))
        local cursor = buf == vim.api.nvim_get_current_buf() and vim.api.nvim_win_get_cursor(0)[1]
        editing[buf] = nil
        for _, heading in ipairs(require("notedown.heading_images").matches(scan, from, to, window_width(buf))) do
          if heading.pos[1] == cursor then
            editing[buf] = cursor
          else
            matches[#matches + 1] = heading
          end
        end
      end
      cb(matches)
    end, opts)
  end

  local placement = require("snacks.image.placement")

  -- Sizes, worked out again whenever the window changes size (snacks updates
  -- placements then, calling on_update_pre first):
  -- * pictures and diagrams at most M.ROWS tall and M.WIDTH of the window
  -- * headings as wide as the window, not snacks' 80 columns, which would draw
  --   long ones smaller than the rest (they already fit the window)
  local new = placement.new
  placement.new = function(buf, src, opts)
    if opts and (opts.type == "image" or opts.type == "chart") then
      opts.on_update_pre = function(p)
        local width = window_width(p.buf)
        if not width then return end
        p.opts.max_width = math.max(1, math.floor(width * M.WIDTH))
        p.opts.max_height = M.ROWS
      end
    elseif opts and opts.type == "heading" then
      opts.max_width = window_width(buf) or opts.max_width
    end
    return new(buf, src, opts)
  end

  -- Every placement goes through _render with its extmarks, so adjust them
  -- there:
  -- * draw images above notedown's own marks on the same lines
  -- * center math, pictures and diagrams on lines of their own in the window;
  --   ones within a line of text stay put
  -- * put a picture's alt text under it as a caption, centered
  -- * keep a picture shown below its line while the cursor is on it
  local render = placement._render
  placement._render = function(self, extmarks)
    local type = self.opts.type
    local centered = type == "math" or type == "image" or type == "chart"
    local offset = centered and centered_offset(self, extmarks)
    for _, extmark in ipairs(extmarks) do
      extmark.priority = extmark.priority or 10001
      if offset and extmark.virt_text_win_col then extmark.virt_text_win_col = offset end
      if offset and extmark.virt_lines then
        for _, line in ipairs(extmark.virt_lines) do
          if line[1] and line[1][2] == nil and line[1][1]:match("^ *$") then table.remove(line, 1) end
          table.insert(line, 1, { (" "):rep(offset) })
        end
      end
    end
    local text = type == "image" and caption(self)
    local under = text and vim.iter(extmarks):rev():find(function(e) return e.virt_lines end)
    if under then
      local pad = math.max(0, math.floor(((window_width(self.buf) or 0) - vim.api.nvim_strwidth(text)) / 2))
      table.insert(under.virt_lines, { { (" "):rep(pad) }, { text, "NotedownImageCaption" } })
    end
    if type == "image" and self.hidden then
      -- drawn as if shown, so snacks doesn't blank it
      self.hidden = false
      render(self, below(self, extmarks))
      self.hidden = true
      return
    end
    render(self, extmarks)
    cover_marker(self)
  end
  local close = placement.close
  placement.close = function(self)
    cover_marker(self, true)
    return close(self)
  end
end

return M
