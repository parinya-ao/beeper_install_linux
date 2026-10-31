#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$root/outside"
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -ne 0
    echo 'FAIL: valid isolated paths rejected'
    rm -rf -- "$root"; exit 1
end
set -e XDG_DATA_HOME XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR
set -lx XDG_DATA_HOME ''
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -ne 0
    echo 'FAIL: standard XDG defaults rejected'
    rm -rf -- "$root"; exit 1
end
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_STATE_HOME /
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: root XDG directory accepted'
    rm -rf -- "$root"; exit 1
end
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CONFIG_HOME "$HOME"
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: HOME used as XDG_CONFIG_HOME'
    rm -rf -- "$root"; exit 1
end
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME /
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: root used as XDG_DATA_HOME'
    rm -rf -- "$root"; exit 1
end
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_CACHE_HOME "$HOME"
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: HOME used as XDG_CACHE_HOME'
    rm -rf -- "$root"; exit 1
end
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR /
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: root used as XDG_RUNTIME_DIR'
    rm -rf -- "$root"; exit 1
end
set -lx XDG_RUNTIME_DIR "$root/runtime"
set -lx XDG_STATE_HOME '$HOME/.local/state'
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: unresolved variable used as XDG_STATE_HOME'
    rm -rf -- "$root"; exit 1
end
set -lx XDG_STATE_HOME "$root/../escape"
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: traversal accepted'
    rm -rf -- "$root"; exit 1
end
set -lx XDG_STATE_HOME "$root/state"
mkdir -p "$HOME/.local/opt"
ln -s "$root/outside" "$HOME/.local/opt/beeper"
fish --private "$project/beeperctl.fish" validate-paths >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: application symlink escape accepted'
    rm -rf -- "$root"; exit 1
end
rm -rf -- "$root"
echo 'PASS: path guards (10 cases)'
