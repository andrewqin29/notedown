init := "tests/minimal_init.lua"
settings := "{ minimal_init = " + quote(init) + ", sequential = true, keep_going = false }"

default: check test bench health

check:
    selene --quiet .
    stylua --check .

test:
    just busted "tests"

bench:
    python scripts/generate.py
    just busted "benches"

[private]
busted path:
    # needed to isolate child processes from user config
    # as plenary does not pass the --clean flag
    XDG_CONFIG_HOME="{{ justfile_directory() }}/config" \
        nvim --headless --noplugin -u {{ init }} \
        -c "PlenaryBustedDirectory {{ path }} {{ settings }}"

health:
    nvim -c "checkhealth notedown" -- -

log:
    cat ~/.local/state/nvim/notedown.log
