local Base = require('notedown.render.base')
local Bullet = require('notedown.render.markdown.bullet')
local Checkbox = require('notedown.render.markdown.checkbox')

---@class notedown.render.List: notedown.Render
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    return true
end

---@protected
function Render:run()
    if not Checkbox:execute(self.context, self.marks, self.node) then
        Bullet:execute(self.context, self.marks, self.node)
    end
end

return Render
