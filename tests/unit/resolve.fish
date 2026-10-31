#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$root/bin"
printf '#!/bin/sh\nprintf "%%s\\n" "$TEST_URL"\n' > "$root/bin/curl"
printf '#!/bin/sh\nprintf "x86_64\\n"\n' > "$root/bin/uname"
chmod +x "$root/bin/curl" "$root/bin/uname"
set -lx PATH "$root/bin" $PATH
set -lx TEST_URL 'https://beeper-desktop.download.beeper.com/builds/Beeper.AppImage'
set -l result (fish --private "$project/beeperctl.fish" resolve-build)
if test $status -ne 0; or test "$result" != "$TEST_URL"
    echo 'FAIL: official final URL should resolve'
    rm -rf -- "$root"; exit 1
end
for url in 'http://beeper.com/build' 'https://beeper.com.evil.invalid/build' 'https://evil.invalid/build'
    set -lx TEST_URL "$url"
    fish --private "$project/beeperctl.fish" resolve-build >/dev/null 2>&1
    if test $status -eq 0
        echo "FAIL: rejected non-official URL $url"
        rm -rf -- "$root"; exit 1
    end
end
rm -rf -- "$root"
echo 'PASS: official redirect validation (4 cases)'
