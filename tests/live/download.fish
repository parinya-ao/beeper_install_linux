#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -g LIVE_TEST_ROOT "$root"
function live_cleanup --on-event fish_exit
    if string match -rq '^/tmp/[^/]+$' -- "$LIVE_TEST_ROOT"
        rm -rf -- "$LIVE_TEST_ROOT"
    end
end
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
for arch in x64 arm64
    set -l endpoint "https://api.beeper.com/desktop/download/linux/$arch/stable/com.automattic.beeper.desktop"
    set -l final (curl --fail --silent --show-error --head --location --retry 2 --connect-timeout 15 --max-time 60 --proto '=https' --proto-redir '=https' --output /dev/null --write-out '%{url_effective}' "$endpoint")
    if test $status -ne 0; or not string match -rq '^https://([a-zA-Z0-9-]+\.)*beeper\.com/[^[:space:]]+$' -- "$final"
        echo "FAIL: $arch official endpoint"; exit 1
    end
    echo "PASS: $arch endpoint → $final"
end
set -l url (fish --private "$project/beeperctl.fish" resolve-build); or exit 1
set -l image "$root/Beeper.AppImage"
set -l final (curl --fail --silent --show-error --location --retry 2 --connect-timeout 15 --max-time 600 --proto '=https' --proto-redir '=https' --output "$image" --write-out '%{url_effective}' "$url")
if test $status -ne 0; or test "$final" != "$url"
    echo 'FAIL: isolated live download'; exit 1
end
chmod 700 "$image"; or exit 1
echo 'PASS: isolated live download'
fish --private "$project/beeperctl.fish" validate-candidate "$image"; or begin
    echo 'FAIL: live AppImage validation'; exit 1
end
echo 'PASS: live AppImage validation'
set -lx LIVE_IMAGE "$image"
set -lx LIVE_URL "$url"
mkdir -p "$root/bin"
printf '%s\n' '#!/bin/sh' 'head=0; out=' 'while [ "$#" -gt 0 ]; do case "$1" in --head) head=1 ;; --output) shift; out=$1 ;; esac; shift; done' '[ "$head" = 1 ] || cp "$LIVE_IMAGE" "$out"' 'printf "%s" "$LIVE_URL"' > "$root/bin/curl"
chmod +x "$root/bin/curl"
set -lx PATH "$root/bin" /usr/bin /bin
fish --private "$project/beeperctl.fish" provision --no-autoupdate; or begin
    echo 'FAIL: isolated provision using the real AppImage'; exit 1
end
if not test -f "$XDG_DATA_HOME/beeper-provision/icon.png"
    echo 'FAIL: official icon extraction'; exit 1
end
fish --private "$project/beeperctl.fish" verify; or begin
    echo 'FAIL: isolated verification using the real AppImage'; exit 1
end
echo 'PASS: isolated real-AppImage provision, icon and verify'
fish --private "$project/beeperctl.fish" uninstall; or begin
    echo 'FAIL: isolated real-AppImage uninstall'; exit 1
end
if test -e "$HOME/.local/opt/beeper"; or test -e "$XDG_DATA_HOME/beeper-provision"
    echo 'FAIL: isolated live artifacts were not removed'; exit 1
end
echo 'PASS: isolated real-AppImage uninstall'
