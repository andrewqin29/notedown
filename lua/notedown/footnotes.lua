-- Footnotes. A reference is [^label] in the text, the label any string
-- without spaces or brackets; its definition is a line "[^label]: text" in the
-- section at the end of the note, which notedown keeps:
--
--   Bits are just bits[^bits], in any context[^ctx].
--
--   [^bits]: The smallest unit of information.
--   [^ctx]: What the program reads them as.
--
-- Footnotes are numbered by where each label is first referenced: each
-- reference shows as its number in superscript (¹ ²), and the section, in a
-- dim grey under a short rule, as "1. text". A label referenced more than once
-- is one footnote. On the cursor's line, both show as typed.
--
-- After each edit (on leaving insert mode, or a normal-mode change) the section
-- is brought up to date: a stub "[^label]: " added for each new label,
-- definitions put in the order of first reference (the blank lines above them
-- kept, however many; at least one), and definitions of labels
-- no longer referenced deleted, along with the text written in them. A
-- definition anywhere else in the note is moved into the section. The update
-- is part of the edit that caused it, so one u undoes both.
--
-- Not in code (fenced, inline or >> blocks), and a reference in a definition's
-- own text doesn't count.

local M = {}

local REF = "()%[%^([^%]%s]+)%]()"
local DEF = "^%[%^([^%]%s]+)%]:%s?(.*)$"

local SUPERSCRIPT = { "⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹" }
local function superscript(n)
  return (tostring(n):gsub("%d", function(d) return SUPERSCRIPT[tonumber(d) + 1] end))
end

-- Byte ranges (1-based, inclusive) of `code` in a line.
local function code_spans(line)
  local ranges = {}
  for from, to in line:gmatch("()`+.-`+()") do ranges[#ranges + 1] = { from, to - 1 } end
  return ranges
end

-- The note's footnotes, from a scan (blocks.lua):
--
--   refs     each reference as { row, col, end_col, label }, cols from 0
--   defs     each definition line as { row, label, text }
--   number   label to its number, by first reference
--   order    labels by number
--   section  first row of the definitions and blank lines ending the note
function M.read(scan)
  local lines = scan.lines
  local section = #lines
  while section > 0 and (lines[section] == "" or lines[section]:match(DEF)) do section = section - 1 end
  local out = { refs = {}, defs = {}, number = {}, order = {}, section = section }
  for i, line in ipairs(lines) do
    local row = i - 1
    if not scan.fenced[row] and not scan.verbatim[row] then
      local label, text = line:match(DEF)
      if label then
        out.defs[#out.defs + 1] = { row = row, label = label, text = text }
      elseif line:find("[^", 1, true) then
        local spans = code_spans(line)
        for from, label_, to in line:gmatch(REF) do
          local in_code = false
          for _, span in ipairs(spans) do
            if from >= span[1] and from <= span[2] then in_code = true end
          end
          if not in_code then
            out.refs[#out.refs + 1] = { row = row, col = from - 1, end_col = to - 1, label = label_ }
            if not out.number[label_] then
              out.order[#out.order + 1] = label_
              out.number[label_] = #out.order
            end
          end
        end
      end
    end
  end
  return out
end

-- Bring the section up to date (see the top of this file).
function M.sync(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].modifiable then return end
  local scan = require("notedown.blocks").scan(buf)
  local notes = M.read(scan)
  if #notes.refs == 0 and #notes.defs == 0 then return end

  -- The text of each label's definition (the first, if written twice).
  local text = {}
  for _, def in ipairs(notes.defs) do
    if text[def.label] == nil then text[def.label] = def.text end
  end
  local section = {}
  for _, label in ipairs(notes.order) do
    section[#section + 1] = "[^" .. label .. "]: " .. (text[label] or "")
  end

  -- What the note should end with, from the first definition or blank line
  -- of its end: the blank lines there before any definition (at least one
  -- above definitions), then the definitions.
  local lines = scan.lines
  local first = notes.section
  local old_tail = vim.list_slice(lines, first + 1, #lines)
  local gap = 0
  while old_tail[gap + 1] == "" do gap = gap + 1 end
  if #section > 0 then gap = math.max(gap, 1) end
  local tail = {}
  for i = 1, gap do tail[i] = "" end
  vim.list_extend(tail, section)

  -- Definitions elsewhere, to delete (from the bottom, so rows stay right).
  local elsewhere = {}
  for _, def in ipairs(notes.defs) do
    if def.row < first then table.insert(elsewhere, 1, def.row) end
  end
  if #elsewhere == 0 and vim.deep_equal(tail, old_tail) then return end

  pcall(vim.cmd.undojoin)
  vim.api.nvim_buf_set_lines(buf, first, -1, false, tail)
  for _, row in ipairs(elsewhere) do
    vim.api.nvim_buf_set_lines(buf, row, row + 1, false, {})
  end
end

-- Called by render.lua on every render.
function M.marks(scan, add)
  local notes = M.read(scan)
  for _, ref in ipairs(notes.refs) do
    add(ref.row, ref.col, true, {
      end_col = ref.end_col,
      conceal = "",
      virt_text = { { superscript(notes.number[ref.label]), "NotedownFootnoteRef" } },
      virt_text_pos = "inline",
    })
  end
  local ruled = false
  for _, def in ipairs(notes.defs) do
    local line = scan.lines[def.row + 1]
    local number = notes.number[def.label]
    local marker = #line - #def.text
    add(def.row, 0, true, {
      end_col = marker,
      conceal = "",
      virt_text = { { number and (number .. ". ") or ("[" .. def.label .. "] "), "NotedownFootnote" } },
      virt_text_pos = "inline",
    })
    if #line > marker then
      add(def.row, marker, false, { end_col = #line, hl_group = "NotedownFootnote", priority = 200 })
    end
    -- A short rule over the blank line above the section.
    local above = def.row - 1
    if not ruled and def.row >= notes.section and above >= 0 and scan.lines[above + 1] == "" then
      ruled = true
      add(above, 0, false, { virt_text = { { ("─"):rep(20), "NotedownFootnote" } }, virt_text_pos = "overlay" })
    end
  end
end

-- Keep the buffer's section up to date (init.lua, for each markdown file).
function M.attach(buf)
  vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
    group = vim.api.nvim_create_augroup("notedown.footnotes." .. buf, { clear = true }),
    buffer = buf,
    callback = function() M.sync(buf) end,
  })
end

return M
