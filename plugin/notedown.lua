if vim.g.loaded_notedown then
    return
end
vim.g.loaded_notedown = true

require('notedown').setup(vim.g.notedown_config)
require('notedown.core.colors').init()
require('notedown.core.command').init()
require('notedown.core.log').init()
require('notedown.core.manager').init()
-- the note format: highlights, commands, snacks.nvim images (notes/init.lua)
if require('notedown.state').notes then
    require('notedown.notes').setup()
end
