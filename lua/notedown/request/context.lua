local str = require('notedown.lib.str')

---@class notedown.request.Context
---@field buf integer
---@field win integer
---@field config notedown.buf.Config
---@field view notedown.request.View
---@field checkbox notedown.request.Checkbox
---@field conceal notedown.request.Conceal
---@field highlights notedown.request.Highlights
---@field inline notedown.request.Inline
---@field used notedown.request.Used
local Context = {}
Context.__index = Context

---@param buf integer
---@param win integer
---@param config notedown.buf.Config
---@param view notedown.request.View
---@return notedown.request.Context
function Context.new(buf, win, config, view)
    local self = setmetatable({}, Context)
    self.buf = buf
    self.win = win
    self.config = config
    self.view = view
    self.checkbox = require('notedown.request.checkbox').new()
    self.conceal = require('notedown.request.conceal').new(self)
    self.highlights =
        require('notedown.request.highlights').new(buf, view)
    self.inline = require('notedown.request.inline').new()
    self.used = require('notedown.request.used').new()
    return self
end

---@param body? notedown.node.Body
---@return integer
function Context:width(body)
    if not body then
        return 0
    end
    return str.width(body.text)
        + self.inline:width(body)
        - self.conceal:get(body)
end

---@class notedown.request.context.Manager
local M = {}

---@private
---@type table<integer, notedown.request.Context>
M.cache = {}

---@param buf integer
---@param win integer
---@return boolean
function M.contains(buf, win)
    local context = M.cache[buf]
    return context and context.view:contains(win) or false
end

---@param buf integer
---@param win integer
---@param config notedown.buf.Config
---@return notedown.request.Context?
function M.new(buf, win, config)
    local view = require('notedown.request.view').new(buf)
    local context = Context.new(buf, win, config, view)
    M.cache[buf] = context
    return context
end

---@param buf integer
---@return notedown.request.Context
function M.get(buf)
    return assert(M.cache[buf], 'missing request context')
end

return M
