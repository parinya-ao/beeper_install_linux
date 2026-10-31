#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$root/bin" "$XDG_CONFIG_HOME/BeeperTexts" "$root/outside"
printf '#!/bin/sh\n[ "${BEEPER_ACTIVE:-0}" = 1 ]\n' > "$root/bin/pgrep"
chmod +x "$root/bin/pgrep"
set -lx PATH "$root/bin" /usr/bin /bin
echo account > "$XDG_CONFIG_HOME/BeeperTexts/account.db"
echo keep > "$root/outside/keep"
fish --private "$project/beeperctl.fish" purge >/dev/null 2>&1
if test $status -eq 0; or not test -f "$XDG_CONFIG_HOME/BeeperTexts/account.db"
    echo 'FAIL: purge requires --user-data'
    rm -rf -- "$root"; exit 1
end
set -lx BEEPER_ACTIVE 1
fish --private "$project/beeperctl.fish" purge --user-data >/dev/null 2>&1
if test $status -eq 0; or not test -f "$XDG_CONFIG_HOME/BeeperTexts/account.db"
    echo 'FAIL: purge must refuse while Beeper is running'
    rm -rf -- "$root"; exit 1
end
set -e BEEPER_ACTIVE
ln -s "$root/outside" "$XDG_CONFIG_HOME/BeeperTexts/escape"
fish --private "$project/beeperctl.fish" purge --user-data >/dev/null 2>&1
if test $status -eq 0; or test (cat "$root/outside/keep") != keep
    echo 'FAIL: purge must refuse nested symlinks'
    rm -rf -- "$root"; exit 1
end
rm "$XDG_CONFIG_HOME/BeeperTexts/escape"
set -l safe_config "$XDG_CONFIG_HOME"
for dangerous in / "$HOME" "$root/../outside"
    set -lx XDG_CONFIG_HOME "$dangerous"
    fish --private "$project/beeperctl.fish" purge --user-data >/dev/null 2>&1
    if test $status -eq 0; or test (cat "$root/outside/keep") != keep
        echo 'FAIL: purge must reject dangerous XDG roots'
        rm -rf -- "$root"; exit 1
    end
end
set -lx XDG_CONFIG_HOME "$safe_config"
fish --private "$project/beeperctl.fish" purge --user-data >/dev/null
if test $status -ne 0; or test -e "$XDG_CONFIG_HOME/BeeperTexts"; or test (cat "$root/outside/keep") != keep
    echo 'FAIL: purge must delete only the observed profile directory'
    rm -rf -- "$root"; exit 1
end
ln -s "$root/outside" "$XDG_CONFIG_HOME/BeeperTexts"
fish --private "$project/beeperctl.fish" purge --user-data >/dev/null 2>&1
if test $status -eq 0; or test (cat "$root/outside/keep") != keep
    echo 'FAIL: purge must refuse a profile symlink escape'
    rm -rf -- "$root"; exit 1
end
rm -rf -- "$root"
echo 'PASS: explicit profile purge and destructive guards (8 cases)'
