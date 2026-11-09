---@module 'luassert'

describe('presets', function()
    ---@param user notedown.UserConfig
    ---@param expected notedown.UserConfig
    local function validate(user, expected)
        local actual = require('notedown.lib.presets').get(user)
        assert.same(expected, actual)
    end

    it('lazy', function()
        validate({
            preset = 'lazy',
        }, {
            file_types = { 'markdown', 'norg', 'rmd', 'org', 'codecompanion' },
            heading = {
                sign = false,
                icons = {},
            },
            checkbox = { enabled = false },
        })
    end)

    it('override', function()
        validate({
            pipe_table = { style = 'normal' },
            overrides = {
                buftype = { nofile = { pipe_table = { style = 'none' } } },
                preview = { pipe_table = { style = 'normal' } },
            },
        }, {
            pipe_table = { border_enabled = false },
            overrides = {
                buftype = { nofile = { pipe_table = { enabled = false } } },
                preview = { pipe_table = { border_enabled = false } },
            },
        })
    end)
end)
