---@module 'luassert'

local state = require('notedown.state')

describe('state', function()
    ---@param config notedown.UserConfig
    ---@param expected string[]
    local function validate(config, expected)
        require('notedown').setup(config)
        assert.same(expected, state.validate())
    end

    ---@param expected any
    ---@param path string[]
    local function option(expected, path)
        local config = state.get(0)
        assert.same(expected, vim.tbl_get(config, unpack(path)))
    end

    it('default', function()
        validate({}, {})
    end)

    it('anti conceal preset', function()
        local path = { 'win_options', 'concealcursor', 'rendered' }

        validate({}, {})
        option('', path)

        validate({ anti_conceal = { enabled = true } }, {})
        option('', path)

        validate({ anti_conceal = { enabled = false } }, {})
        option('nvic', path)
    end)

    it('valid', function()
        local config = {
            enabled = false,
            render_modes = {},
            anti_conceal = {},
            heading = {},
            dash = {},
            bullet = {},
            checkbox = { unchecked = {}, checked = {} },
            quote = {},
            pipe_table = {},
            win_options = {},
        }
        validate(config, {})
    end)

    it('extra', function()
        local config = {
            additional = true,
            anti_conceal = { ignore = { additional = true } },
            checkbox = { checked = { additional = true } },
        }
        local expected = {
            'additional - expected: nil, got: boolean',
            'anti_conceal.ignore.additional - expected: nil, got: boolean',
            'checkbox.checked.additional - expected: nil, got: boolean',
        }
        validate(config, expected)
    end)

    it('type', function()
        local config = {
            anti_conceal = { ignore = { quote = 'invalid' } },
            bullet = { icons = 0 },
            checkbox = { checked = false, unchecked = { icon = false } },
            debounce = {},
            enabled = 'invalid',
            heading = { enabled = 'invalid' },
            log_level = 'invalid',
            log_runtime = 'invalid',
            padding = { highlight = true },
            render_modes = 'invalid',
        }
        local expected = {
            'anti_conceal.ignore.quote - expected: string[]|boolean, got: "invalid"',
            'bullet.icons - expected: string|string[]|string[][]|function, got: 0',
            'checkbox.checked - expected: table, got: boolean',
            'checkbox.unchecked.icon - expected: string, got: boolean',
            'debounce - expected: number, got: table',
            'enabled - expected: boolean, got: string',
            'heading.enabled - expected: boolean, got: string',
            'log_level - expected: "debug"|"error"|"info"|"off"|"trace"|"warn", got: "invalid"',
            'log_runtime - expected: boolean, got: string',
            'padding.highlight - expected: string, got: boolean',
            'render_modes - expected: string[]|boolean, got: "invalid"',
        }
        validate(config, expected)
    end)

    it('value', function()
        local config = {
            checkbox = 'invalid',
            render_modes = { 1, 2 },
        }
        local expected = {
            'checkbox - expected: table, got: string',
            'render_modes - expected: string[]|boolean, got: { 1, 2 }',
        }
        validate(config, expected)
    end)
end)
