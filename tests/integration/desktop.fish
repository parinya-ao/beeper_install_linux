#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/"'home with % and $dollar = "quote" and `tick` and \slash'
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
set -lx TEST_LOG "$root/launched"
mkdir -p "$HOME/.local/opt/beeper" "$XDG_RUNTIME_DIR" "$XDG_DATA_HOME/applications"
set -l app "$HOME/.local/opt/beeper/Beeper.AppImage"
set -l desktop "$XDG_DATA_HOME/applications/beeper.desktop"
printf '%s\n' '#!/bin/sh' 'if [ "$1" = --appimage-extract ]; then' '  [ "${FAIL_ICON:-0}" != 1 ] || exit 1' '  mkdir -p squashfs-root/usr/share/icons/hicolor/512x512/apps' '  printf "\211PNG\r\n\032\n" > squashfs-root/usr/share/icons/hicolor/512x512/apps/beepertexts.png' '  exit 0' 'fi' 'printf "%s" "$1" > "$TEST_LOG"' > "$app"
printf 'beeper-provision\n' > "$HOME/.local/opt/beeper/.beeper-provision-owned"
chmod +x "$app"
echo unrelated > "$desktop"
fish --private "$project/beeperctl.fish" integrate >/dev/null 2>&1
if test $status -eq 0; or test (cat "$desktop") != unrelated
    echo 'FAIL: unrelated desktop entry must not be overwritten'
    rm -rf -- "$root"; exit 1
end
rm "$desktop"
fish --private "$project/beeperctl.fish" integrate >/dev/null
if test $status -ne 0; or not test -f "$desktop"
    echo 'FAIL: desktop entry was not created'
    rm -rf -- "$root"; exit 1
end
if command -sq desktop-file-validate; and not desktop-file-validate "$desktop"
    echo 'FAIL: desktop entry failed validation'
    rm -rf -- "$root"; exit 1
end
if not test -f "$XDG_DATA_HOME/beeper-provision/icon.png"; or not string match -q "*Icon=$XDG_DATA_HOME/beeper-provision/icon.png*" -- (string collect < "$desktop")
    echo 'FAIL: desktop integration must prefer the AppImage icon'
    rm -rf -- "$root"; exit 1
end
if command -sq gio
    gio launch "$desktop" 'beeper://test/path' >/dev/null 2>&1
    for attempt in (seq 100)
        test -e "$TEST_LOG"; and break
        sleep 0.05
    end
    if not test -f "$TEST_LOG"; or test (cat "$TEST_LOG") != 'beeper://test/path'
        echo 'FAIL: desktop launcher must execute the correct path and forward URL'
        rm -rf -- "$root"; exit 1
    end
else if not string match -q 'Exec=*%U' -- (string collect < "$desktop")
    echo 'FAIL: desktop launcher must forward URLs when gio is unavailable'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" integrate >/dev/null
if test $status -ne 0
    echo 'FAIL: desktop integration must be idempotent'
    rm -rf -- "$root"; exit 1
end
set -l isolated_path "$root/optional-tools-absent"
mkdir -p "$isolated_path"
for name in fish realpath seq grep mkdir mktemp rm od timeout cp mv env cat flock stat
    set -l binary /usr/bin/fish
    if test "$name" != fish
        set binary (command -s "$name")
    end
    if test -z "$binary"; or not ln -s "$binary" "$isolated_path/$name"
        echo "FAIL: could not prepare isolated tool path for $name"
        rm -rf -- "$root"; exit 1
    end
end
set -l original_path $PATH
set -lx PATH "$isolated_path"
set -lx FAIL_ICON 1
fish --private "$project/beeperctl.fish" integrate > "$root/optional.log" 2>&1
set -l optional_status $status
set -lx PATH $original_path
set -e FAIL_ICON
if test $optional_status -ne 0; or not grep -Fxq 'Icon=applications-internet' "$desktop"
    echo "FAIL: missing optional desktop tools and icon extraction failure must remain nonfatal (status=$optional_status)"
    string collect < "$root/optional.log"
    grep '^Icon=' "$desktop"
    rm -rf -- "$root"; exit 1
end
set -lx ICON_FALLBACK_URL 'https://www.beeper.com/wp-content/uploads/2026/05/beeper-favicon.png'
set -lx ICON_CURL_LOG "$root/icon-curl.log"
printf '%s\n' '#!/bin/sh' 'out=' 'url=' 'while [ "$#" -gt 0 ]; do case "$1" in --output) shift; out=$1 ;; --write-out) shift ;; esac; url=$1; shift; done' '[ "$url" = "$ICON_FALLBACK_URL" ] || exit 22' 'final=${ICON_EFFECTIVE_URL:-$ICON_FALLBACK_URL}' 'if [ "${ICON_BAD_PNG:-0}" = 1 ]; then printf "not-a-png-fallback" > "$out"; else printf "\\211PNG\\r\\n\\032\\nX" > "$out"; fi' 'printf "%s" "$final" > "$ICON_CURL_LOG"' 'printf "%s" "$final"' > "$isolated_path/curl"
chmod +x "$isolated_path/curl"
set -lx PATH "$isolated_path"
set -lx FAIL_ICON 1
fish --private "$project/beeperctl.fish" integrate > "$root/official-icon.log" 2>&1
set -l official_icon_status $status
set -e FAIL_ICON
if test $official_icon_status -ne 0; or not grep -Fxq "Icon=$XDG_DATA_HOME/beeper-provision/icon.png" "$desktop"; or not test -f "$XDG_DATA_HOME/beeper-provision/icon.png"; or test (string collect < "$ICON_CURL_LOG") != "$ICON_FALLBACK_URL"
    echo 'FAIL: icon extraction failure must fall back to the verified official Beeper asset'
    string collect < "$root/official-icon.log"
    grep '^Icon=' "$desktop"
    rm -rf -- "$root"; exit 1
end
set -lx ICON_EFFECTIVE_URL 'https://evil.example/icon.png'
set -lx FAIL_ICON 1
fish --private "$project/beeperctl.fish" integrate > "$root/redirect.log" 2>&1
set -l redirect_status $status
set -e FAIL_ICON
if test $redirect_status -ne 0; or not grep -Fxq 'Icon=applications-internet' "$desktop"
    echo 'FAIL: icon fallback must reject redirects outside the exact official asset URL'
    echo "status=$redirect_status"
    string collect < "$ICON_CURL_LOG"
    string collect < "$root/redirect.log"
    grep '^Icon=' "$desktop"
    rm -rf -- "$root"; exit 1
end
set -e ICON_EFFECTIVE_URL
set -lx ICON_BAD_PNG 1
set -lx FAIL_ICON 1
fish --private "$project/beeperctl.fish" integrate >/dev/null 2>&1
set -e FAIL_ICON
set -lx PATH $original_path
if test $status -ne 0; or not grep -Fxq 'Icon=applications-internet' "$desktop"
    echo 'FAIL: icon fallback must reject non-PNG responses'
    rm -rf -- "$root"; exit 1
end
set -e ICON_BAD_PNG
fish --private "$project/beeperctl.fish" uninstall >/dev/null
if test $status -ne 0; or test -e "$XDG_DATA_HOME/beeper-provision/icon.png"
    echo 'FAIL: uninstall must remove the manager-owned icon'
    rm -rf -- "$root"; exit 1
end
rm -rf -- "$root"
echo 'PASS: desktop ownership, icon, launch, idempotence, optional-tool fallback and removal (9 cases)'
