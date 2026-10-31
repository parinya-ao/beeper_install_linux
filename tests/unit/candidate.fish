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
printf '#!/bin/sh\nprintf "64\\n"\nexit "${TEST_RUNTIME_STATUS:-0}"\n' > "$root/bin/timeout"
chmod +x "$root/bin/timeout"
set -lx PATH "$root/bin" $PATH
set -l candidate "$root/candidate"
touch "$candidate"
chmod +x "$candidate"
fish --private "$project/beeperctl.fish" validate-candidate "$candidate" >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: empty candidate accepted'
    rm -rf -- "$root"; exit 1
end
truncate -s 1048576 "$candidate"
fish --private "$project/beeperctl.fish" validate-candidate "$candidate" >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: invalid candidate accepted'
    rm -rf -- "$root"; exit 1
end
printf '\177ELF' | dd of="$candidate" bs=1 seek=0 conv=notrunc status=none
printf 'AI\002' | dd of="$candidate" bs=1 seek=8 conv=notrunc status=none
printf 'hsqs' | dd of="$candidate" bs=1 seek=64 conv=notrunc status=none
fish --private "$project/beeperctl.fish" validate-candidate "$candidate" >/dev/null 2>&1
if test $status -ne 0
    echo 'FAIL: valid Type-2 candidate rejected'
    rm -rf -- "$root"; exit 1
end
printf '\000\000\000' | dd of="$candidate" bs=1 seek=8 conv=notrunc status=none
fish --private "$project/beeperctl.fish" validate-candidate "$candidate" >/dev/null 2>&1
if test $status -ne 0
    echo 'FAIL: Type-2 runtime with absent optional magic must be accepted'
    rm -rf -- "$root"; exit 1
end
printf 'AI\001' | dd of="$candidate" bs=1 seek=8 conv=notrunc status=none
fish --private "$project/beeperctl.fish" validate-candidate "$candidate" >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: Type-1 magic must not be accepted as Type-2'
    rm -rf -- "$root"; exit 1
end
printf 'AI\002' | dd of="$candidate" bs=1 seek=8 conv=notrunc status=none
set -lx TEST_RUNTIME_STATUS 1
fish --private "$project/beeperctl.fish" validate-candidate "$candidate" >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: a failing runtime must not be accepted even when it prints an offset'
    rm -rf -- "$root"; exit 1
end
rm -rf -- "$root"
echo 'PASS: candidate validation (6 cases)'
