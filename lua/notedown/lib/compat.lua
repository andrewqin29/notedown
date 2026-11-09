---@class notedown.Compat
local M = {}

---@param cause string
function M.release(cause)
    local message = {
        'MeanderingProgrammer/notedown',
        cause,
        'you are running an old build of neovim that has now been released',
        'your build does not have all the features that are in the release',
        'update your build or switch to the release version',
    }
    vim.schedule(function()
        vim.notify_once(table.concat(message, '\n'), vim.log.levels.ERROR)
    end)
end

return M
