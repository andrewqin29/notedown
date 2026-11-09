---@module 'luassert'

describe('presets', function()
    ---@param user notedown.UserConfig
    ---@param expected notedown.UserConfig
    local function validate(user, expected)
        local actual = require('notedown.lib.presets').get(user)
        assert.same(expected, actual)
    end

    it('table style', function()
        validate({ pipe_table = { style = 'normal' } }, {
            pipe_table = { border_enabled = false },
        })
    end)
end)
