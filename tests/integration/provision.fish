#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
set -lx FIXTURE "$root/fixture"
set -lx SYSTEMCTL_LOG "$root/systemctl.log"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$root/bin" "$XDG_DATA_HOME/applications"
truncate -s 1048576 "$FIXTURE"
printf '\177ELF' | dd of="$FIXTURE" bs=1 seek=0 conv=notrunc status=none
printf 'AI\002' | dd of="$FIXTURE" bs=1 seek=8 conv=notrunc status=none
printf 'hsqs' | dd of="$FIXTURE" bs=1 seek=64 conv=notrunc status=none
printf '#!/bin/sh\nprintf "64\\n"\n' > "$root/bin/timeout"
printf '%s\n' '#!/bin/sh' 'head=0; out=' 'while [ "$#" -gt 0 ]; do case "$1" in --head) head=1 ;; --output) shift; out=$1 ;; esac; shift; done' '[ "$head" = 1 ] || cp "$FIXTURE" "$out"' 'printf "https://beeper.com/builds/one.AppImage"' > "$root/bin/curl"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$SYSTEMCTL_LOG"\nexit "${SYSTEMCTL_STATUS:-0}"\n' > "$root/bin/systemctl"
chmod +x "$root/bin/timeout" "$root/bin/curl" "$root/bin/systemctl"
set -lx PATH "$root/bin" /usr/bin /bin
set -l desktop "$XDG_DATA_HOME/applications/beeper.desktop"
set -l app "$HOME/.local/opt/beeper/Beeper.AppImage"
echo unrelated > "$desktop"
fish --private "$project/beeperctl.fish" provision --no-autoupdate >/dev/null 2>&1
if test $status -eq 0; or test -e "$app"; or test (cat "$desktop") != unrelated
    echo 'FAIL: provisioning must preflight collisions before installation'
    rm -rf -- "$root"; exit 1
end
rm "$desktop"
set -lx SYSTEMCTL_STATUS 1
fish --private "$project/beeperctl.fish" provision >/dev/null 2>&1
if test $status -eq 0; or test -e "$app"
    echo 'FAIL: automatic provisioning must check the user systemd manager before installation'
    rm -rf -- "$root"; exit 1
end
set -e SYSTEMCTL_STATUS
rm -f "$SYSTEMCTL_LOG"
for attempt in 1 2 3
    fish --private "$project/beeperctl.fish" provision --no-autoupdate >/dev/null
    if test $status -ne 0; or not test -x "$app"; or not test -x "$HOME/.local/bin/beeperctl"; or not test -f "$desktop"; or test -e "$app.prev"; or test -e "$SYSTEMCTL_LOG"
        echo 'FAIL: no-autoupdate provisioning must converge without enabling a timer'
        rm -rf -- "$root"; exit 1
    end
end
rm "$desktop"
fish --private "$project/beeperctl.fish" provision >/dev/null
if test $status -ne 0; or not test -f "$desktop"; or not test -f "$XDG_CONFIG_HOME/systemd/user/beeper-update.timer"; or not string match -q '*--user enable --now beeper-update.timer*' -- (string collect < "$SYSTEMCTL_LOG")
    echo 'FAIL: provisioning must repair desktop drift and enable the daily timer'
    rm -rf -- "$root"; exit 1
end
for attempt in 1 2
    fish --private "$project/beeperctl.fish" provision >/dev/null
    if test $status -ne 0; or not test -x "$app"; or test -e "$app.prev"; or test (find "$XDG_DATA_HOME/applications" -maxdepth 1 -name 'beeper.desktop' | count) -ne 1; or test (find "$XDG_CONFIG_HOME/systemd/user" -maxdepth 1 -name 'beeper-update.*' | count) -ne 2
        echo 'FAIL: repeated default provisioning must converge without duplicate artifacts or backups'
        rm -rf -- "$root"; exit 1
    end
end
fish --private "$project/beeperctl.fish" verify >/dev/null
if test $status -ne 0
    echo 'FAIL: verify must accept a healthy isolated installation'
    rm -rf -- "$root"; exit 1
end
string replace -r '^Exec=.*' 'Exec=/bin/true %U' < "$desktop" > "$root/wrong.desktop"
mv "$root/wrong.desktop" "$desktop"
fish --private "$project/beeperctl.fish" verify >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: verify must reject a valid-looking launcher with the wrong executable'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" integrate >/dev/null; or exit 1
set -l service "$XDG_CONFIG_HOME/systemd/user/beeper-update.service"
set -l timer "$XDG_CONFIG_HOME/systemd/user/beeper-update.timer"
string replace -r '^ExecStart=.*' 'ExecStart=/bin/true' < "$service" > "$root/wrong.service"
mv "$root/wrong.service" "$service"
fish --private "$project/beeperctl.fish" verify >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: verify must reject a timer service with the wrong controller'
    rm -rf -- "$root"; exit 1
end
rm "$timer"
fish --private "$project/beeperctl.fish" autoupdate enable >/dev/null; or exit 1
if not test -f "$timer"
    echo 'FAIL: enabling automatic updates must restore a missing timer unit'
    rm -rf -- "$root"; exit 1
end
chmod -x "$app"
fish --private "$project/beeperctl.fish" verify >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: verify must reject a non-executable AppImage'
    rm -rf -- "$root"; exit 1
end
chmod +x "$app"
touch "$XDG_STATE_HOME/beeper-provision/transaction"
fish --private "$project/beeperctl.fish" verify >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: verify must reject an unreconciled transaction'
    rm -rf -- "$root"; exit 1
end
rm "$XDG_STATE_HOME/beeper-provision/transaction"
printf '#!/bin/sh\nprintf "glibc 2.31\\n"\n' > "$root/bin/getconf"
chmod +x "$root/bin/getconf"
set -l diagnosis (fish --private "$project/beeperctl.fish" doctor | string collect)
if not string match -q '*FAIL: glibc*' -- "$diagnosis"; or not string match -q '*PASS: official endpoint*' -- "$diagnosis"; or not string match -q '*UNKNOWN: extract-and-run*' -- "$diagnosis"
    echo 'FAIL: doctor must distinguish old glibc, reachable endpoint, and unproven fallback'
    rm -rf -- "$root"; exit 1
end
rm "$root/bin/getconf"
rm "$app"
fish --private "$project/beeperctl.fish" provision >/dev/null
if test $status -ne 0; or not test -x "$app"
    echo 'FAIL: provisioning must reinstall a missing binary despite installed metadata'
    rm -rf -- "$root"; exit 1
end
mkdir -p "$XDG_CONFIG_HOME/Beeper"
echo profile > "$XDG_CONFIG_HOME/Beeper/profile"
echo important > "$HOME/.local/opt/beeper/unrelated-file"
fish --private "$project/beeperctl.fish" uninstall >/dev/null 2>&1
if test $status -eq 0; or not test -e "$app"; or test (cat "$HOME/.local/opt/beeper/unrelated-file") != important
    echo 'FAIL: uninstall must refuse unexpected files before deleting artifacts'
    rm -rf -- "$root"; exit 1
end
rm "$HOME/.local/opt/beeper/unrelated-file"
ln -s "$XDG_CONFIG_HOME/Beeper/profile" "$HOME/.local/opt/beeper/.candidate.evil"
fish --private "$project/beeperctl.fish" uninstall >/dev/null 2>&1
if test $status -eq 0; or test (cat "$XDG_CONFIG_HOME/Beeper/profile") != profile
    echo 'FAIL: uninstall must refuse a symlink in its owned directory'
    rm -rf -- "$root"; exit 1
end
rm "$HOME/.local/opt/beeper/.candidate.evil"
fish --private "$project/beeperctl.fish" uninstall >/dev/null
if test $status -ne 0; or test -e "$app"; or test -e "$desktop"; or test -e "$HOME/.local/bin/beeperctl"; or test -e "$XDG_CONFIG_HOME/systemd/user/beeper-update.timer"; or test -e "$XDG_STATE_HOME/beeper-provision"; or test -e "$XDG_CACHE_HOME/beeper-provision"; or test (cat "$XDG_CONFIG_HOME/Beeper/profile") != profile; or not string match -q '*--user disable --now beeper-update.timer*' -- (string collect < "$SYSTEMCTL_LOG")
    echo 'FAIL: uninstall must remove managed artifacts and preserve profile data'
    rm -rf -- "$root"; exit 1
end
rm -rf -- "$root"
echo 'PASS: provisioning, preflight, drift, timer, verify, doctor, uninstall safety (17 cases)'
