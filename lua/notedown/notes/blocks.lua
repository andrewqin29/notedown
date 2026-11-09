-- Callout blocks without a > on every line, for notedown:
--
--   >> note            (or tip, important, warning, caution)
--   hello
--   this is a note
--   <<
--
-- renders like GitHub's "> [!NOTE]" callout: a colored title line, then a bar
-- in front of every line of the block, wrapped lines included. Text after the
-- tag replaces the title (">> tip Keyboard shortcuts"). Tags are written in
-- lowercase; capitals work the same (">> NOTE").
--
--   >> latex
--   x^2 = y^3
--   \sum_{i=1}^{n} i \leq \frac{n^2}{2}
--   <<
--
-- shows the formulas typeset, one per line and centered, as an image made with
-- pdflatex by snacks.nvim's image module (see M.setup_snacks). The LaTeX shows
-- while the cursor is in the block. A block that already starts with \begin
-- (aligned, cases, ...) is typeset as it is.
--
-- Where images can't be shown (a terminal without kitty's graphics protocol),
-- the block shows as typed, as a mermaid block does.
--
--   >> mermaid
--   graph LR
--     source --> compiler --> program
--   <<
--
-- shows the diagram as an image made by mermaid-cli (mmdc), sized and centered
-- like other images, in colors to match (assets/mermaid/config.json).
--
--   >> boxed
--   Chapter 1: A Tour of Computer Systems
--   <<
--
-- shows its lines in white inside a box drawn with line characters, as wide as
-- the longest line, with a column of room either side.
--
-- A block shows only once its << is there, and not inside fenced code blocks.
-- The marker lines of a callout show as typed while the cursor is on them. This
-- isn't markdown, so other markdown viewers (GitHub included) show the >> and
-- << lines as they are.

local M = {}

-- Icons and colors match notedown's own callouts.
M.kinds = {
  note      = { icon = "󰋽", title = "Note",      hl = "NotedownInfo" },
  tip       = { icon = "󰌶", title = "Tip",       hl = "NotedownSuccess" },
  important = { icon = "󰅾", title = "Important", hl = "NotedownHint" },
  warning   = { icon = "󰀪", title = "Warning",   hl = "NotedownWarn" },
  caution   = { icon = "󰳦", title = "Caution",   hl = "NotedownError" },
  latex     = { math = true,                     hl = "NotedownMath" },
  mermaid   = { chart = true,                    hl = "NotedownMath" },
  boxed     = { box = true,                      hl = "NotesBoxBorder" },
}

-- Note blocks have a background in their color, mixed this much into the
-- editor's background, behind the whole block.
M.TINT = 0.12

local function blend(fg, bg, amount)
  local function channel(shift)
    local a, b = bit.band(bit.rshift(fg, shift), 0xff), bit.band(bit.rshift(bg, shift), 0xff)
    return bit.lshift(math.floor(b + (a - b) * amount + 0.5), shift)
  end
  return bit.bor(channel(16), channel(8), channel(0))
end

-- For each note block kind: NotesCallout<Kind>Bg (the tint) and
-- NotesCallout<Kind> (its color on the tint, for the bar and title). Set again
-- when the colorscheme changes.
function M.define_highlights()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg or 0
  for key, kind in pairs(M.kinds) do
    if kind.icon then
      local fg = vim.api.nvim_get_hl(0, { name = kind.hl, link = false }).fg or 0xffffff
      local name = "NotesCallout" .. key:sub(1, 1):upper() .. key:sub(2)
      local tint = blend(fg, normal, M.TINT)
      vim.api.nvim_set_hl(0, name .. "Bg", { bg = tint })
      vim.api.nvim_set_hl(0, name, { fg = fg, bg = tint })
      kind.bg, kind.fg = name .. "Bg", name
    end
  end
  -- Image captions, dim and italic; ==highlights==, bright yellow.
  local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false }).fg
  vim.api.nvim_set_hl(0, "NotesImageCaption", { fg = comment, italic = true })
  vim.api.nvim_set_hl(0, "NotesHighlight", { bg = "#ffd700", fg = "#000000" })
  -- Inline `code` gets a background here: the notedown fork has no code
  -- rendering of its own (notes/init.lua).
  vim.api.nvim_set_hl(0, "@markup.raw.markdown_inline", { link = "NotedownCodeInline" })
  -- >> boxed blocks: white text, the border in the text's dimmer color.
  vim.api.nvim_set_hl(0, "NotesBoxText", { fg = "#ffffff" })
  vim.api.nvim_set_hl(0, "NotesBoxBorder", { fg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg })
end

-- Code blocks: ">> python" ... "<<" shows the code highlighted as that language
-- (with its tree-sitter parser), like a ```python block. Tag to parser name.
M.code = {
  python = "python", py = "python",
  c = "c",
  cpp = "cpp", ["c++"] = "cpp",
  java = "java",
  rust = "rust", rs = "rust",
  ocaml = "ocaml", ml = "ocaml",
}

local function kind_for(tag)
  if M.kinds[tag] then return M.kinds[tag] end
  if M.code[tag] then return { code = M.code[tag], name = tag } end
end

local BAR = "▋"

-- Largest size of an image (not math or a heading): rows tall, and share of
-- the window's width.
M.IMAGE_ROWS = 20
M.IMAGE_WIDTH = 0.8

-- How far in a wrapped line continues while notedown renders, with
-- 'breakindentopt' list:-1 (notes/init.lua): as many columns as
-- 'formatlistpat' matches at the start of the line. Each match below is as long
-- as the rendered prefix in front of the text, so wrapped lines continue under
-- the text. Lines that match nothing, like paragraphs, continue at the left.
--
--   "- [ ] x"  5: two columns of list indent, then the checkbox and a space
--   "- x"      4: the indent, then "● " (hence the 2 extra characters matched)
--   "1. x"     5: the indent, then "1. "
--   "> x"      2: the bar and a space, for each level of quote
M.list_pattern = table.concat({
  [=[^\s*[-*+]\s\+\[[ xX-]\]]=],
  [=[^\s*[-*+]\s\+\S.]=],
  [=[^\s*\d\+[.)]\s\+\S.]=],
  [=[^\%(>\s\?\)\+]=],
}, [[\|]])

-- Lines in a >> block have a bar in front that isn't in the text, so no pattern
-- can know to indent them. Instead, each render adds one alternative per line
-- in a block, matching that line's own start, 2 columns longer than usual.
local function set_list_pattern(buf, lines, blocks)
  local extra = {}
  for _, block in ipairs(blocks) do
    if not block.kind.math and not block.kind.code and not block.kind.chart and not block.kind.box then
      for row = block.first + 1, block.last - 1 do
        local line = lines[row + 1]
        if line:find("%S") then
          local match = vim.fn.matchstrpos(line, M.list_pattern)
          local width = 2 + (match[2] >= 0 and match[3] - match[2] or 0)
          local start = vim.fn.escape(vim.fn.strcharpart(line, 0, 40), [[\]])
          extra[#extra + 1] = [[^\%(\V]] .. start .. [[\m\)\@=]] .. ("."):rep(width)
        end
      end
    end
  end
  extra[#extra + 1] = M.list_pattern
  local pattern = table.concat(extra, [[\|]])
  if vim.bo[buf].formatlistpat ~= pattern then vim.bo[buf].formatlistpat = pattern end
end

-- Each block as { first, last, kind, title }, rows counted from 0.
local function find_blocks(lines)
  local blocks, open, fence = {}, nil, nil
  for i, line in ipairs(lines) do
    local row = i - 1
    local marker = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
    if marker and not open then
      if not fence then
        fence = marker
      elseif marker:sub(1, 1) == fence:sub(1, 1) and #marker >= #fence then
        fence = nil
      end
    elseif open then
      -- Inside a block only its end counts, so code can contain ">> x" lines.
      if line:match("^<<%s*$") then
        open.last = row
        blocks[#blocks + 1] = open
        open = nil
      end
    elseif not fence then
      local tag, title = line:match("^>>%s*([%w%+#]+)%s*(.-)%s*$")
      local kind = tag and kind_for(tag:lower())
      if kind then open = { first = row, kind = kind, title = title } end
    end
  end
  return blocks
end
M.find_blocks = find_blocks

-- -------------------------------------------------------------------- code

-- Highlighted code by language and text, so a render parses only code it
-- hasn't seen.
local highlighted_cache = {}

-- The code's lines as virtual lines: highlighted by the language's tree-sitter
-- highlights, on the code block background, padded to the longest line.
local function highlighted(code, lang)
  local text = table.concat(code, "\n")
  local key = lang .. "\0" .. text
  if highlighted_cache[key] then return highlighted_cache[key] end

  -- The highlight group at each byte, later (more specific) captures winning.
  local groups = {}
  for row = 1, #code do groups[row] = {} end
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, lang)
  local query = ok and vim.treesitter.query.get(lang, "highlights")
  if query then
    local tree = parser:parse()[1]
    for id, node in query:iter_captures(tree:root(), text) do
      local name = query.captures[id]
      if not name:find("^_") and name ~= "spell" and name ~= "nospell" and name ~= "conceal" then
        local group = "@" .. name .. "." .. lang
        local start_row, start_col, end_row, end_col = node:range()
        for row = start_row, math.min(end_row, #code - 1) do
          local from = row == start_row and start_col or 0
          local to = row == end_row and end_col or #code[row + 1]
          for col = from, to - 1 do groups[row + 1][col] = group end
        end
      end
    end
  end

  local tab = (" "):rep(vim.bo.tabstop)
  local width = 0
  for _, line in ipairs(code) do width = math.max(width, vim.fn.strdisplaywidth((line:gsub("\t", tab)))) end

  local bg = "NotedownCode"
  local out = {}
  for row, line in ipairs(code) do
    local chunks = { { " ", bg } }
    local start = 0
    for col = 1, #line do
      if col == #line or groups[row][col] ~= groups[row][start] then
        local group = groups[row][start]
        chunks[#chunks + 1] = { line:sub(start + 1, col):gsub("\t", tab), group and { bg, group } or bg }
        start = col
      end
    end
    local shown = vim.fn.strdisplaywidth((line:gsub("\t", tab)))
    chunks[#chunks + 1] = { (" "):rep(width - shown + 1), bg }
    out[row] = chunks
  end
  highlighted_cache[key] = out
  return out
end

-- -------------------------------------------------------- typeset (snacks)

-- The block's LaTeX as one display: each line its own centered formula.
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

-- notedown reads a >> latex or mermaid block's ">>" as two nested quotes and draws
-- a bar over each >. Cover them: with blanks while the image shows (centered,
-- it no longer covers them itself), and with the >> while the LaTeX shows for
-- editing (cursor in the block, so snacks hides the image).
local marker_ns = vim.api.nvim_create_namespace("notedown.notes.latex_marker")
local markers = {} -- extmark id by placement id

function M.latex_marker(placement, closing)
  local range, id = placement.opts.range, markers[placement.id]
  local line = range and vim.api.nvim_buf_get_lines(placement.buf, range[1] - 1, range[1], false)[1]
  local typed = placement.opts.type == "math" or placement.opts.type == "chart"
  if not closing and typed and line and line:match("^>>") then
    markers[placement.id] = vim.api.nvim_buf_set_extmark(placement.buf, marker_ns, range[1] - 1, 0, {
      id = id,
      virt_text = { { placement.hidden and ">>" or "  ", "NotedownMath" } },
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
function M.centered_offset(placement, extmarks)
  local range = placement.opts.range
  if not range then return nil end
  local lines = vim.api.nvim_buf_get_lines(placement.buf, range[1] - 1, range[3], false)
  if #lines == 0 or lines[1]:sub(1, range[2]):find("%S")
      or lines[#lines]:sub(range[4] + 1):find("%S") then
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
  local win = require("notedown.notes.window")(placement.buf)
  if width == 0 or not win then return nil end
  local info = vim.fn.getwininfo(win)[1]
  return math.max(0, math.floor((info.width - info.textoff - width) / 2))
end

-- An image's caption: the alt text of the ![alt](...) its line holds.
local function caption(placement)
  local range = placement.opts.range
  local line = range and vim.api.nvim_buf_get_lines(placement.buf, range[1] - 1, range[1], false)[1]
  local alt = line and line:match("!%[(.-)%]")
  return alt and vim.trim(alt) ~= "" and vim.trim(alt) or nil
end

-- Send every image snacks has sent to the terminal again, and place each of its
-- placements again. snacks keeps its images in a table private to its image
-- module, reached here through the function that adds to it.
function M.resend_images()
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

-- snacks finds the math it typesets with tree-sitter, which can't see these
-- blocks, so add them to what it finds, built the way it builds a ```math block.
function M.setup_snacks()
  -- If anything asked snacks for the terminal's capabilities before the
  -- terminal answered, snacks remembers an answer without Ghostty in it, and
  -- shows no inline images all session. Forget it once the answer is in, before
  -- snacks sets up images in any buffer (which waits for the same answer).
  local terminal = require("snacks.image.terminal")
  terminal.detect(function()
    terminal._env = nil
  end)

  -- Ghostty can lose images when its window is resized (another pane opening
  -- beside it, say), but snacks sends each image only once, so images placed
  -- again after a resize point at nothing and don't show. Send every image
  -- again once a resize settles (after snacks' own update, 100 ms after it).
  local resend = Snacks.util.debounce(M.resend_images, { ms = 300 })
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("notedown.notes.resend_images", { clear = true }),
    callback = function() resend() end,
  })

  local doc = require("snacks.image.doc")
  local find = doc.find
  doc.find = function(buf, cb, opts)
    find(buf, function(matches)
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "markdown" then
        -- Of what snacks finds itself, only images and inline $math$: ```math,
        -- $$...$$ and ```mermaid aren't part of the format (>> latex and
        -- >> mermaid replace them, notes/legacy.lua).
        -- (By now a formula's content is a whole LaTeX document, so look at the
        -- note's own text where it is.)
        matches = vim.tbl_filter(function(m)
          if m.type == "image" then return true end
          if m.type ~= "math" or not m.range then return false end
          local r = m.range
          local ok, text = pcall(vim.api.nvim_buf_get_text, buf, r[1] - 1, r[2], r[3] - 1, r[4], {})
          local source = ok and table.concat(text, "\n") or ""
          return source:find("^%$") ~= nil and source:find("^%$%$") == nil
        end, matches)
        local from, to = opts and opts.from, opts and opts.to
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        for _, block in ipairs(find_blocks(lines)) do
          local visible = not from or (block.last + 1 >= from and block.first + 1 <= to)
          local tex = block.kind.math and visible and block_latex(lines, block)
          if tex then
            local img = {
              id = "latex-block-" .. block.first,
              lang = "markdown",
              type = "math",
              ext = "math.tex",
              content = tex,
              pos = { block.first + 1, 0 },
              range = { block.first + 1, 0, block.last + 1, #lines[block.last + 1] },
            }
            doc.transforms.latex(img, { buf = buf })
            local root = Snacks.image.config.cache
            vim.fn.mkdir(root, "p")
            img.src = root .. "/" .. vim.fn.sha256(img.content):sub(1, 8) .. "-content.math.tex"
            if vim.fn.filereadable(img.src) == 0 then
              local file = assert(io.open(img.src, "w"))
              file:write(img.content)
              file:close()
            end
            matches[#matches + 1] = img
          end
          if block.kind.chart and visible and block.last > block.first + 1 then
            local content = table.concat(vim.list_slice(lines, block.first + 2, block.last), "\n")
            local root = Snacks.image.config.cache
            vim.fn.mkdir(root, "p")
            local src = root .. "/" .. vim.fn.sha256(content):sub(1, 8) .. "-content.chart.mmd"
            if vim.fn.filereadable(src) == 0 then
              local file = assert(io.open(src, "w"))
              file:write(content)
              file:close()
            end
            matches[#matches + 1] = {
              id = "mermaid-block-" .. block.first,
              lang = "markdown",
              type = "chart",
              ext = "chart.mmd",
              src = src,
              pos = { block.first + 1, 0 },
              range = { block.first + 1, 0, block.last + 1, #lines[block.last + 1] },
            }
          end
        end
        -- Bigger # and ## headings, drawn as images too, except "# ..." lines
        -- inside >> blocks (a comment in a python block, say).
        local skip = {}
        for _, block in ipairs(find_blocks(lines)) do
          for row = block.first, block.last do skip[row + 1] = true end
        end
        vim.list_extend(matches, require("notedown.notes.heading_images").matches(buf, lines, from, to, skip))
      end
      cb(matches)
    end, opts)
  end

  -- Every image placement goes through _render with its extmarks, so adjust
  -- them there:
  -- * Draw images above everything else: notedown reads ">>" as two
  --   nested quotes and draws a bar over each >, on top of the image.
  -- * Center math, images and diagrams that are on lines of their own ($$...$$,
  --   ```math, >> latex, ![](...), >> mermaid) in the window. Ones within a
  --   line of text stay put.
  -- * Put an image's alt text under it as a caption, centered.
  local placement = require("snacks.image.placement")
  require("notedown.notes.heading_images").patch_placement(placement)

  -- Images (pasted screenshots, say) and diagrams keep their shape but are at most
  -- M.IMAGE_ROWS rows tall and M.IMAGE_WIDTH of the window's width, worked out
  -- again whenever the window changes size (snacks updates placements then,
  -- calling on_update_pre first).
  local new = placement.new
  placement.new = function(buf, src, opts)
    if opts and (opts.type == "image" or opts.type == "chart") then
      opts.on_update_pre = function(p)
        local win = require("notedown.notes.window")(p.buf)
        if not win then return end
        local info = vim.fn.getwininfo(win)[1]
        p.opts.max_width = math.max(1, math.floor((info.width - info.textoff) * M.IMAGE_WIDTH))
        p.opts.max_height = M.IMAGE_ROWS
      end
    end
    return new(buf, src, opts)
  end
  local render = placement._render
  placement._render = function(self, extmarks)
    local type = self.opts.type
    local centered = type == "math" or type == "image" or type == "chart"
    local offset = centered and M.centered_offset(self, extmarks)
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
    local below = text and vim.iter(extmarks):rev():find(function(e) return e.virt_lines end)
    if below then
      local win = require("notedown.notes.window")(self.buf)
      local info = win and vim.fn.getwininfo(win)[1]
      local width = info and (info.width - info.textoff) or 0
      local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))
      table.insert(below.virt_lines, { { (" "):rep(pad) }, { text, "NotesImageCaption" } })
    end
    render(self, extmarks)
    M.latex_marker(self)
  end
  local close = placement.close
  placement.close = function(self)
    M.latex_marker(self, true)
    return close(self)
  end

end

-- ------------------------------------------------------------------- marks

-- Called by notedown on every render, alongside its own handlers.
function M.parse(ctx)
  -- Once per buffer: it's called for each markdown tree, and this reads the
  -- whole buffer.
  if not ctx.last then return {} end

  local lines = vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)
  local marks = {}
  local function add(row, col, conceal, opts)
    marks[#marks + 1] = { conceal = conceal, start_row = row, start_col = col, opts = opts }
  end

  local blocks = find_blocks(lines)
  set_list_pattern(ctx.buf, lines, blocks)

  -- Justified paragraphs (notes/justify.lua): not in >> code, latex or
  -- mermaid blocks or on >> and << lines. Lines in a note block start after its
  -- 2-column bar, on its tint.
  if not M.kinds.note.bg then M.define_highlights() end
  local skip, indent, bg = {}, {}, {}
  for _, block in ipairs(blocks) do
    skip[block.first], skip[block.last] = true, true
    for row = block.first + 1, block.last - 1 do
      if block.kind.code or block.kind.math or block.kind.chart or block.kind.box then
        skip[row] = true
      else
        indent[row], bg[row] = 2, block.kind.bg
      end
    end
  end
  require("notedown.notes.justify").marks(ctx.buf, lines, skip, indent, bg, add)
  -- Dashes, curly quotes, fractions and symbols (notes/typography.lua), in
  -- the same places.
  require("notedown.notes.typography").marks(lines, skip, add)

  for _, block in ipairs(blocks) do
    local hl, kind = block.kind.hl, block.kind

    if kind.code then
      -- The >> line becomes a label (the language's icon and name), the code
      -- shows highlighted below it, and the code's own lines and the << are
      -- hidden. The code's lines come back while the cursor is in them; on
      -- the >> line it shows as typed.
      local icon, icon_hl = require("nvim-web-devicons").get_icon_by_filetype(kind.code)
      add(block.first, 0, true, {
        virt_text = { { (icon or "") .. " ", icon_hl or "NotedownCodeInfo" } },
        virt_text_pos = "overlay",
        priority = 10000,
      })
      add(block.first, 2, true, {
        end_col = #lines[block.first + 1],
        conceal = "",
        virt_text = { { kind.name, "NotedownCodeInfo" } },
        virt_text_pos = "inline",
      })
      local code = vim.list_slice(lines, block.first + 2, block.last)
      if #code > 0 then
        add(block.first, 0, true, { end_row = block.last, virt_lines = highlighted(code, kind.code) })
      end
      add(block.first + 1, 0, true, {
        end_row = block.last,
        end_col = #lines[block.last + 1],
        conceal_lines = "",
      })
    elseif kind.box then
      -- A box around the lines: the top border over the >> line, "│ " before
      -- each line and " │" after it (padded to the longest), and the bottom
      -- border over the <<. The >> and << lines show as typed while the cursor
      -- is on them.
      local width = vim.fn.strdisplaywidth(lines[block.first + 1]) - 4
      for row = block.first + 1, block.last - 1 do
        width = math.max(width, vim.fn.strdisplaywidth(lines[row + 1]))
      end
      local border = "NotesBoxBorder"
      add(block.first, 0, true, {
        virt_text = { { "┌" .. ("─"):rep(width + 2) .. "┐", border } },
        virt_text_pos = "overlay",
        priority = 10000,
      })
      for row = block.first + 1, block.last - 1 do
        local line = lines[row + 1]
        add(row, 0, false, {
          virt_text = { { "│ ", border } },
          virt_text_pos = "inline",
          right_gravity = false,
        })
        if #line > 0 then
          add(row, 0, false, { end_col = #line, hl_group = "NotesBoxText", priority = 200 })
        end
        add(row, #line, false, {
          virt_text = { { (" "):rep(width - vim.fn.strdisplaywidth(line) + 1) .. "│", border } },
          virt_text_pos = "inline",
        })
      end
      add(block.last, 0, true, {
        virt_text = { { "└" .. ("─"):rep(width + 2) .. "┘", border } },
        virt_text_pos = "overlay",
        priority = 10000,
      })
    elseif kind.chart or kind.math then
      -- snacks draws the diagram or the typeset formulas over the block (see
      -- M.setup_snacks); without images the source just shows.
    else
      local title = block.title ~= "" and block.title or kind.title
      -- The bar and title in the kind's color on its tint, which is behind the
      -- whole block: the title line and every line in it, wrapped ones too.
      hl = kind.fg or hl
      for row = block.first, block.last - 1 do
        add(row, 0, false, { line_hl_group = kind.bg })
      end

      -- Title line. notedown reads ">>" as two nested quotes and draws
      -- its own bar over each >, so draw this bar and a space over them instead
      -- (a higher priority wins), then hide the rest and show the title there.
      add(block.first, 0, true, {
        virt_text = { { BAR .. " ", hl } },
        virt_text_pos = "overlay",
        priority = 10000,
      })
      add(block.first, 2, true, {
        end_col = #lines[block.first + 1],
        conceal = "",
        virt_text = { { kind.icon .. " " .. title, hl } },
        virt_text_pos = "inline",
      })

      -- Every line in between: a bar pushes the text over, and a second bar at
      -- the window's left edge repeats on each wrapped line, which starts 2
      -- columns in (set_list_pattern). The first goes before notedown's
      -- list indent, so a list in a block is indented within the block.
      for row = block.first + 1, block.last - 1 do
        add(row, 0, false, {
          virt_text = { { BAR .. " ", hl } },
          virt_text_pos = "inline",
          right_gravity = false,
          priority = 0,
        })
        add(row, 0, false, {
          virt_text = { { BAR, hl } },
          virt_text_win_col = 0,
          virt_text_repeat_linebreak = true,
        })
      end

      -- The << line takes no room.
      add(block.last, 0, true, { end_col = #lines[block.last + 1], conceal_lines = "" })
    end
  end

  return marks
end

return M
