#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
mkdir -p "$HOME/.local/bin" "$XDG_RUNTIME_DIR"
set -l manager "$HOME/.local/bin/beeperctl"
printf 'unrelated\n' > "$manager"
fish --private "$project/beeperctl.fish" install-controller >/dev/null 2>&1
if test $status -eq 0; or test (cat "$manager") != unrelated
    echo 'FAIL: unrelated controller must not be overwritten'
    rm -rf -- "$root"; exit 1
end
rm "$manager"
fish --private "$project/beeperctl.fish" install-controller >/dev/null
if test $status -ne 0; or not test -x "$manager"; or not cmp -s "$manager" "$project/beeperctl.fish"
    echo 'FAIL: manager must be installed executable with matching content'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" install-controller >/dev/null
if test $status -ne 0
    echo 'FAIL: manager installation must be idempotent'
    rm -rf -- "$root"; exit 1
end
rm -rf -- "$root"
echo 'PASS: manager ownership and installation (3 cases)'
