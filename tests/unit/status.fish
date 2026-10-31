#!/usr/bin/env fish
set -l root (mktemp -d)
or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_CACHE_HOME "$root/cache"
mkdir -p "$HOME"
mkdir -p "$root/bin"
set -lx TEST_NETWORK_FLAG "$root/network-used"
printf '#!/bin/sh\ntouch "$TEST_NETWORK_FLAG"\nexit 1\n' > "$root/bin/curl"
chmod +x "$root/bin/curl"
set -lx PATH "$root/bin" /usr/bin /bin

set -l result (fish --private "$project/beeperctl.fish" status 2>&1)
set -l result_status $status
if test $result_status -ne 0; or not string match -q '*not installed*' -- "$result"
    echo "FAIL: offline status reports an absent installation"
    rm -rf -- "$root"
    exit 1
end

fish --private "$project/beeperctl.fish" purge >/dev/null 2>&1
if test $status -eq 0
    echo "FAIL: purge must refuse unverified data paths"
    rm -rf -- "$root"
    exit 1
end
if test -e "$XDG_DATA_HOME/beeper"; or test -e "$XDG_CONFIG_HOME/beeper"; or test -e "$XDG_CACHE_HOME/beeper"
    echo "FAIL: read-only commands created manager files"
    rm -rf -- "$root"
    exit 1
end
if test -e "$TEST_NETWORK_FLAG"
    echo 'FAIL: status contacted the network'
    rm -rf -- "$root"
    exit 1
end
set -l app "$HOME/.local/opt/beeper"
set -lx XDG_STATE_HOME "$root/state"
mkdir -p "$app" "$XDG_STATE_HOME/beeper-provision"
printf 'fixture' > "$app/Beeper.AppImage"
chmod +x "$app/Beeper.AppImage"
printf 'previous' > "$app/Beeper.AppImage.prev"
printf 'https://example.invalid/build\n' > "$XDG_STATE_HOME/beeper-provision/current-url"
set result (fish --private "$project/beeperctl.fish" status 2>&1 | string collect)
if not string match -q '*Beeper: installed*' -- "$result"; or not string match -q "*$app/Beeper.AppImage*" -- "$result"; or not string match -q '*Rollback: available*' -- "$result"; or not string match -q '*https://example.invalid/build*' -- "$result"
    echo 'FAIL: status must describe the actual user-local binary, rollback, and build'
    rm -rf -- "$root"
    exit 1
end
rm -rf -- "$root"
echo 'PASS: offline status and safe purge'
