#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
set -lx TEST_LOG "$root/launch.log"
mkdir -p "$HOME/.local/opt/beeper" "$XDG_RUNTIME_DIR"
printf '#!/bin/sh\nprintf "%%s|%%s|%%s\\n" "${APPIMAGE_EXTRACT_AND_RUN:-normal}" "${electron_ozone_platform_hint:-default}" "$1" > "$TEST_LOG"\n' > "$HOME/.local/opt/beeper/Beeper.AppImage"
chmod +x "$HOME/.local/opt/beeper/Beeper.AppImage"
fish --private "$project/beeperctl.fish" run 'beeper://hello'
if test "$status" -ne 0; or test (cat "$TEST_LOG") != 'normal|default|beeper://hello'
    echo 'FAIL: normal launch should pass its arguments without extra flags'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" run-extract 'beeper://hello'
if test "$status" -ne 0; or test (cat "$TEST_LOG") != '1|default|beeper://hello'
    echo 'FAIL: extract fallback must set APPIMAGE_EXTRACT_AND_RUN'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" run-wayland 'beeper://hello'
if test "$status" -ne 0; or test (cat "$TEST_LOG") != 'normal|auto|beeper://hello'
    echo 'FAIL: explicit Wayland workaround must set the upstream-documented hint'
    rm -rf -- "$root"; exit 1
end
set -l smoke_output (fish --private "$project/beeperctl.fish" smoke 2>&1 | string collect)
set -l smoke_status $pipestatus[1]
if test $smoke_status -eq 0; or not string match -q '*exited*' -- "$smoke_output"
    echo 'FAIL: smoke must report an early exit as failure'
    rm -rf -- "$root"; exit 1
end
printf '#!/bin/sh\nprintf "%%s" "$$" > "$TEST_LOG"\nexec sleep 20\n' > "$HOME/.local/opt/beeper/Beeper.AppImage"
set smoke_output (fish --private "$project/beeperctl.fish" smoke 2>&1 | string collect)
set smoke_status $pipestatus[1]
if test $smoke_status -ne 0; or not string match -q '*GUI health is not verified*' -- "$smoke_output"
    echo 'FAIL: smoke must report only process survival'
    test -f "$TEST_LOG"; and kill (cat "$TEST_LOG") 2>/dev/null
    rm -rf -- "$root"; exit 1
end
kill (cat "$TEST_LOG") 2>/dev/null
rm -rf -- "$root"
echo 'PASS: normal, extract, Wayland, and smoke launch (5 cases)'
