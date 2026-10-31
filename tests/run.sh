#!/bin/sh
set -eu
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT HUP INT TERM
mkdir -p "$root/home" "$root/runtime"
case "${1:-all}" in
    all) set -- tests/unit/*.fish tests/integration/*.fish tests/safety/*.fish ;;
    unit|integration|safety|live) set -- "tests/$1/"*.fish ;;
    *) echo "Unknown test group" >&2; exit 2 ;;
esac
for test_file do
    env -i PATH=/usr/bin:/bin HOME="$root/home" \
        XDG_CONFIG_HOME="$root/config" XDG_DATA_HOME="$root/data" \
        XDG_STATE_HOME="$root/state" XDG_CACHE_HOME="$root/cache" \
        XDG_RUNTIME_DIR="$root/runtime" fish --private "$test_file"
done
