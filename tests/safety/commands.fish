#!/usr/bin/env fish
set -l project (path resolve (dirname (status filename))/../..)
if grep -En '(^|[[:space:];|&])(sudo|zypper|apt|apt-get|dnf|pacman|flatpak|snap)([[:space:];|&]|$)' "$project/beeperctl.fish"
    echo 'FAIL: privileged or package-manager command in controller'
    exit 1
end
if grep -Eq '^\[tools\]$|^\[tools\.' "$project/mise.toml"
    echo 'FAIL: mise must use the installed baseline without managed tools'
    exit 1
end
echo 'PASS: no privileged or package-manager commands'
