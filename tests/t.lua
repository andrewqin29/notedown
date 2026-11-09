-- The test runner and its helpers. Specs (tests/*_spec.lua) call t.test(name,
-- fn); every test runs in one coroutine, so t.wait can hand control back to
-- nvim's main loop (renders, typed keys) and carry on after.

local M = {}

M.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
-- With --update, snapshots are written instead of compared.
M.update = false

local tests, file = {}, nil
local co

function M.test(name, fn)
  tests[#tests + 1] = { file = file, name = name, fn = fn }
end

-- Let nvim run for ms (renders are scheduled, and debounced 100 ms after a
-- change).
function M.wait(ms)
  vim.defer_fn(function() assert(coroutine.resume(co)) end, ms or 0)
  coroutine.yield()
end

function M.settle()
  M.wait(150)
end

-- Keys as typed, then a moment for them to take effect.
function M.keys(keys)
  vim.api.nvim_input(keys)
  M.wait(50)
end

function M.eq(actual, expected, what)
  if not vim.deep_equal(actual, expected) then
    error(("%sexpected %s, got %s"):format(what and (what .. ": ") or "", vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

function M.ok(value, what)
  if not value then error((what or "expected true") .. ", got " .. vim.inspect(value), 2) end
end

-- A markdown file in the current window, rendered. lines end with a blank
-- line the cursor goes to, so every line of the note shows rendered.
function M.open(lines, name)
  lines = vim.list_extend(vim.deepcopy(lines), { "" })
  local path = vim.fn.tempname() .. "/" .. (name or "note") .. ".md"
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.api.nvim_win_set_cursor(0, { #lines, 0 })
  M.settle()
  return vim.api.nvim_get_current_buf()
end

-- A buffer holding lines, not shown and not a file.
function M.scratch(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

function M.cursor(row)
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
  M.settle()
end

-- The screen's text, each line without its trailing spaces, up to the last
-- line with anything on it.
function M.screen()
  vim.cmd("redraw")
  local rows = {}
  for row = 1, vim.o.lines do
    local line = ""
    for col = 1, vim.o.columns do line = line .. vim.fn.screenstring(row, col) end
    rows[row] = (line:gsub("%s+$", ""))
  end
  while #rows > 0 and (rows[#rows] == "" or rows[#rows] == "~") do rows[#rows] = nil end
  return rows
end

-- The screen below the window's winbar (the breadcrumb).
function M.body()
  local rows = M.screen()
  if vim.wo.winbar ~= "" then table.remove(rows, 1) end
  return rows
end

-- notedown's marks in the buffer, one line each, in order.
function M.marks(buf)
  local ns = vim.api.nvim_get_namespaces().notedown
  local out = {}
  for _, m in ipairs(vim.api.nvim_buf_get_extmarks(buf or 0, ns, 0, -1, { details = true })) do
    local d = m[4]
    local function chunks(list)
      local parts = {}
      for _, c in ipairs(list) do
        local hl = type(c[2]) == "table" and table.concat(c[2], "+") or c[2]
        parts[#parts + 1] = vim.inspect(c[1]) .. (hl and (":" .. hl) or "")
      end
      return table.concat(parts, " ")
    end
    local fields = { ("%d:%d"):format(m[2], m[3]) }
    if d.end_row then fields[#fields + 1] = ("to %d:%d"):format(d.end_row, d.end_col) end
    if d.virt_text then fields[#fields + 1] = d.virt_text_pos .. " " .. chunks(d.virt_text) end
    if d.virt_text_win_col then fields[#fields + 1] = "win_col " .. d.virt_text_win_col end
    if d.virt_text_repeat_linebreak then fields[#fields + 1] = "repeat" end
    if d.conceal then fields[#fields + 1] = "conceal " .. vim.inspect(d.conceal) end
    if d.conceal_lines then fields[#fields + 1] = "conceal_lines" end
    if d.hl_group then fields[#fields + 1] = "hl " .. d.hl_group end
    if d.line_hl_group then fields[#fields + 1] = "line_hl " .. d.line_hl_group end
    if d.virt_lines then
      for _, line in ipairs(d.virt_lines) do fields[#fields + 1] = "\n      line " .. chunks(line) end
    end
    out[#out + 1] = table.concat(fields, "  ")
  end
  return out
end

-- Compare text with tests/snapshots/<name>.txt (or write it, with --update
-- or when there's none yet).
function M.snapshot(name, text)
  local path = M.root .. "/tests/snapshots/" .. name .. ".txt"
  local lines = vim.split(text, "\n")
  if M.update or vim.fn.filereadable(path) == 0 then
    vim.fn.mkdir(vim.fs.dirname(path), "p")
    vim.fn.writefile(lines, path)
    return
  end
  local expected = table.concat(vim.fn.readfile(path), "\n")
  if expected ~= text then
    local diff = (vim.text and vim.text.diff or vim.diff)(expected .. "\n", text .. "\n", { ctxlen = 1 })
    error(("snapshot %s differs (run with --update to accept):\n%s"):format(name, diff), 2)
  end
end

-- Back to one window and no buffers, notedown on.
local function reset()
  vim.cmd("silent! only")
  vim.cmd("silent! %bwipeout!")
  vim.o.columns, vim.o.lines = 80, 40
  require("notedown.render").enabled = true
end

function M.run(paths, filter)
  for _, path in ipairs(paths) do
    file = vim.fn.fnamemodify(path, ":t:r")
    dofile(path)
  end
  local failed, passed = {}, 0
  co = coroutine.create(function()
    for _, test in ipairs(tests) do
      local label = test.file .. ": " .. test.name
      if not filter or label:find(filter, 1, true) then
        reset()
        local ok, err = xpcall(test.fn, debug.traceback)
        if ok then
          passed = passed + 1
        else
          failed[#failed + 1] = label .. "\n    " .. err:gsub("\n", "\n    ")
        end
      end
    end
    local out = {}
    for _, f in ipairs(failed) do out[#out + 1] = "FAIL " .. f end
    out[#out + 1] = ("%d passed, %d failed"):format(passed, #failed)
    io.stdout:write("\n" .. table.concat(out, "\n") .. "\n")
    vim.cmd(#failed == 0 and "qa!" or "cquit 1")
  end)
  assert(coroutine.resume(co))
end

return M
