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
printf '#!/bin/sh\nprintf "%%s\\n" "$TEST_ARCH"\n' > "$root/bin/uname"
chmod +x "$root/bin/uname"
set -lx PATH "$root/bin" $PATH
for pair in x86_64:x64 amd64:x64 aarch64:arm64 arm64:arm64
    set -l parts (string split : "$pair")
    set -lx TEST_ARCH $parts[1]
    set -l actual (fish --private "$project/beeperctl.fish" architecture)
    if test "$status" -ne 0; or test "$actual" != "$parts[2]"
        echo "FAIL: $parts[1] maps to $parts[2], got $actual"
        rm -rf -- "$root"
        exit 1
    end
end
set -lx TEST_ARCH riscv64
fish --private "$project/beeperctl.fish" architecture >/dev/null 2>&1
if test $status -eq 0
    echo 'FAIL: unsupported architecture accepted'
    rm -rf -- "$root"
    exit 1
end
rm -rf -- "$root"
echo 'PASS: architecture mapping and rejection (5 cases)'
