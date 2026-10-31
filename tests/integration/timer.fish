#!/usr/bin/env fish
set -l root (mktemp -d); or exit 1
set -l project (path resolve (dirname (status filename))/../..)
set -lx HOME "$root/home with % and \$dollar"
set -lx XDG_CONFIG_HOME "$root/config"
set -lx XDG_DATA_HOME "$root/data"
set -lx XDG_STATE_HOME "$root/state"
set -lx XDG_CACHE_HOME "$root/cache"
set -lx XDG_RUNTIME_DIR "$root/runtime"
set -lx SYSTEMCTL_LOG "$root/systemctl.log"
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$root/bin" "$XDG_CONFIG_HOME/systemd/user"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$SYSTEMCTL_LOG"\nexit "${SYSTEMCTL_STATUS:-0}"\n' > "$root/bin/systemctl"
chmod +x "$root/bin/systemctl"
set -lx PATH "$root/bin" /usr/bin /bin
fish --private "$project/beeperctl.fish" install-controller >/dev/null; or exit 1
set -l service "$XDG_CONFIG_HOME/systemd/user/beeper-update.service"
set -l timer "$XDG_CONFIG_HOME/systemd/user/beeper-update.timer"
echo unrelated > "$service"
fish --private "$project/beeperctl.fish" autoupdate enable >/dev/null 2>&1
if test $status -eq 0; or test (cat "$service") != unrelated
    echo 'FAIL: unrelated service must not be overwritten'
    rm -rf -- "$root"; exit 1
end
rm "$service"
fish --private "$project/beeperctl.fish" autoupdate enable >/dev/null
if test $status -ne 0; or not test -f "$service"; or not test -f "$timer"; or not string match -q '*OnCalendar=daily*Persistent=true*RandomizedDelaySec=*' -- (string collect < "$timer"); or not string match -q '*%%*$dollar*update --non-interactive*' -- (string collect < "$service"); or not string match -q "*Environment=\"XDG_STATE_HOME=$XDG_STATE_HOME\"*" -- (string collect < "$service"); or not string match -q '*--user enable --now beeper-update.timer*' -- (string collect < "$SYSTEMCTL_LOG")
    echo 'FAIL: timer enable must generate escaped units and enable the user timer'
    rm -rf -- "$root"; exit 1
end
if command -sq systemd-analyze
    systemd-analyze --user verify "$service" "$timer" >/dev/null
    if test $status -ne 0
        echo 'FAIL: systemd rejected generated units'
        rm -rf -- "$root"; exit 1
    end
end
fish --private "$project/beeperctl.fish" autoupdate status >/dev/null
if test $status -ne 0; or not string match -q '*--user is-enabled beeper-update.timer*' -- (string collect < "$SYSTEMCTL_LOG")
    echo 'FAIL: timer status must query the user timer'
    rm -rf -- "$root"; exit 1
end
mkdir -p "$XDG_CONFIG_HOME/systemd/user/timers.target.wants"
ln -s ../beeper-update.timer "$XDG_CONFIG_HOME/systemd/user/timers.target.wants/beeper-update.timer"
fish --private "$project/beeperctl.fish" autoupdate disable >/dev/null
if test $status -ne 0; or not string match -q '*--user disable --now beeper-update.timer*' -- (string collect < "$SYSTEMCTL_LOG")
    echo 'FAIL: timer disable must target the user timer'
    rm -rf -- "$root"; exit 1
end
set -lx SYSTEMCTL_STATUS 1
fish --private "$project/beeperctl.fish" autoupdate status >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: timer status must preserve systemd disabled/failure status'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" autoupdate enable >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: systemd failure must be visible'
    rm -rf -- "$root"; exit 1
end
rm -rf -- "$root"
echo 'PASS: user timer ownership, units, lifecycle, status, failure (5 cases)'
