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
set -lx TEST_CURL_LOG "$root/curl.log"
set -lx FAIL_METADATA_MARK "$root/metadata-failed"
set -lx RUNTIME_MARK "$root/runtime-checked"
set -lx RECOVERY_MARK "$root/recovery-checked"
set -lx BUILD_URL 'https://beeper-desktop.download.beeper.com/builds/one.AppImage'
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$root/bin"
truncate -s 1048576 "$FIXTURE"
printf '\177ELF' | dd of="$FIXTURE" bs=1 seek=0 conv=notrunc status=none
printf 'AI\002' | dd of="$FIXTURE" bs=1 seek=8 conv=notrunc status=none
printf 'hsqs' | dd of="$FIXTURE" bs=1 seek=64 conv=notrunc status=none
printf '%s\n' '#!/bin/sh' 'if [ "${FAIL_RECOVERY_CHECK:-0}" = 1 ] && [ "$2" = "$HOME/.local/opt/beeper/Beeper.AppImage" ] && [ ! -e "$RECOVERY_MARK" ]; then : > "$RECOVERY_MARK"; exit 1; fi' 'if [ "${FAIL_SECOND_CHECK:-0}" = 1 ]; then' '  printf "check\n" >> "$RUNTIME_MARK"' '  [ "$(wc -l < "$RUNTIME_MARK")" -ge 3 ] && exit 1' 'fi' 'printf "64\n"' > "$root/bin/timeout"
printf '%s\n' '#!/bin/sh' 'head=0' 'out=' 'while [ "$#" -gt 0 ]; do' '  case "$1" in --head) head=1 ;; --output) shift; out=$1 ;; esac' '  shift' 'done' 'if [ "$head" = 1 ]; then printf "head\n" >> "$TEST_CURL_LOG"; [ "${FAIL_RESOLVE:-0}" = 1 ] && exit 22; printf "%s" "$BUILD_URL"; else printf "get\n" >> "$TEST_CURL_LOG"; [ "${FAIL_DOWNLOAD:-0}" = 1 ] && exit 22; cp "$FIXTURE" "$out" && printf "%s" "$BUILD_URL"; fi' > "$root/bin/curl"
chmod +x "$root/bin/timeout" "$root/bin/curl"
set -lx PATH "$root/bin" /usr/bin /bin
fish --private "$project/beeperctl.fish" update
set -l app "$HOME/.local/opt/beeper/Beeper.AppImage"
if test $status -ne 0; or not test -x "$app"; or not cmp -s "$FIXTURE" "$app"; or test -e "$app.prev"; or not test -f "$XDG_STATE_HOME/beeper-provision/current-url"; or test (cat "$XDG_STATE_HOME/beeper-provision/current-url") != "$BUILD_URL"
    echo 'FAIL: fresh update must install and record the validated build without a rollback'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" rollback >/dev/null 2>&1
if test $status -eq 0; or not cmp -s "$FIXTURE" "$app"
    echo 'FAIL: rollback without a previous build must fail without changing current'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" update >/dev/null
set -l update_status $status
set -l downloads (string match get < "$TEST_CURL_LOG")
if test $update_status -ne 0; or test (count $downloads) -ne 1; or test -e "$app.prev"
    echo 'FAIL: unchanged build must skip download and preserve rollback state'
    rm -rf -- "$root"; exit 1
end
cp "$app" "$root/old"
printf 'new' | dd of="$FIXTURE" bs=1 seek=128 conv=notrunc status=none
set -lx BUILD_URL 'https://beeper-desktop.download.beeper.com/builds/two.AppImage'
fish --private "$project/beeperctl.fish" update >/dev/null
if test $status -ne 0; or not cmp -s "$FIXTURE" "$app"; or not cmp -s "$root/old" "$app.prev"; or test (cat "$XDG_STATE_HOME/beeper-provision/current-url") != "$BUILD_URL"; or test (cat "$XDG_STATE_HOME/beeper-provision/previous-url") != 'https://beeper-desktop.download.beeper.com/builds/one.AppImage'
    echo 'FAIL: update must atomically retain the previous build and metadata'
    rm -rf -- "$root"; exit 1
end
cp "$app" "$root/current"
set -lx BUILD_URL 'https://beeper-desktop.download.beeper.com/builds/three.AppImage'
set -lx FAIL_DOWNLOAD 1
fish --private "$project/beeperctl.fish" update >/dev/null 2>&1
if test $status -eq 0; or not cmp -s "$root/current" "$app"; or not cmp -s "$root/old" "$app.prev"; or test (cat "$XDG_STATE_HOME/beeper-provision/current-url") != 'https://beeper-desktop.download.beeper.com/builds/two.AppImage'; or test (count "$XDG_CACHE_HOME"/beeper-provision/candidate.*) -ne 0
    echo 'FAIL: failed download must preserve current, rollback, metadata, and clean cache'
    rm -rf -- "$root"; exit 1
end
if not test -f "$XDG_STATE_HOME/beeper-provision/last-update"; or not string match -q '*failed*' -- (string collect < "$XDG_STATE_HOME/beeper-provision/last-update")
    echo 'FAIL: update failure must be recorded for offline status'
    rm -rf -- "$root"; exit 1
end
set -e FAIL_DOWNLOAD
printf 'newest' | dd of="$FIXTURE" bs=1 seek=128 conv=notrunc status=none
set -lx FAIL_SECOND_CHECK 1
fish --private "$project/beeperctl.fish" update >/dev/null 2>&1
if test $status -eq 0; or not cmp -s "$root/current" "$app"; or test (cat "$XDG_STATE_HOME/beeper-provision/current-url") != 'https://beeper-desktop.download.beeper.com/builds/two.AppImage'
    echo 'FAIL: post-promotion validation failure must restore the previous current build'
    rm -rf -- "$root"; exit 1
end
set -e FAIL_SECOND_CHECK
printf '%s\n' '#!/bin/sh' 'last=' 'for arg do last=$arg; done' 'case "$last" in */current-url) if [ ! -e "$FAIL_METADATA_MARK" ]; then : > "$FAIL_METADATA_MARK"; exit 1; fi ;; esac' 'exec /usr/bin/mv "$@"' > "$root/bin/mv"
chmod +x "$root/bin/mv"
fish --private "$project/beeperctl.fish" update >/dev/null 2>&1
if test $status -eq 0; or not test -f "$FAIL_METADATA_MARK"; or not cmp -s "$root/current" "$app"; or test -e "$XDG_STATE_HOME/beeper-provision/transaction"; or test (cat "$XDG_STATE_HOME/beeper-provision/current-url") != 'https://beeper-desktop.download.beeper.com/builds/two.AppImage'
    echo 'FAIL: metadata failure after promotion must restore current binary and metadata'
    rm -rf -- "$root"; exit 1
end
printf '%s\n' '#!/bin/sh' 'last=' 'for arg do last=$arg; done' 'case "$last" in */current-url) kill -KILL "$PPID"; exit 1 ;; esac' 'exec /usr/bin/mv "$@"' > "$root/bin/mv"
fish --private "$project/beeperctl.fish" update >/dev/null 2>&1
set -l interrupted_status $status
if test $interrupted_status -eq 0; or not test -f "$XDG_STATE_HOME/beeper-provision/transaction"; or begin; not cmp -s "$FIXTURE" "$app"; and not cmp -s "$root/current" "$app"; end
    echo 'FAIL: interrupted promotion must leave a transaction marker and a whole binary'
    rm -rf -- "$root"; exit 1
end
rm "$root/bin/mv"
fish --private "$project/beeperctl.fish" update
if test $status -ne 0; or test -e "$XDG_STATE_HOME/beeper-provision/transaction"; or test (cat "$XDG_STATE_HOME/beeper-provision/current-url") != "$BUILD_URL"; or not cmp -s "$root/current" "$app.prev"
    echo 'FAIL: next update must reconcile an interrupted promotion'
    rm -rf -- "$root"; exit 1
end
if test (count (find "$XDG_STATE_HOME/beeper-provision" -maxdepth 1 -name '.meta.*')) -ne 0
    echo 'FAIL: recovery must clean interrupted metadata staging files'
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" rollback >/dev/null
if test $status -ne 0; or not cmp -s "$root/current" "$app"; or not cmp -s "$FIXTURE" "$app.prev"; or test (cat "$XDG_STATE_HOME/beeper-provision/current-url") != 'https://beeper-desktop.download.beeper.com/builds/two.AppImage'; or test (cat "$XDG_STATE_HOME/beeper-provision/previous-url") != "$BUILD_URL"
    echo 'FAIL: rollback must swap current and previous builds and their metadata'
    rm -rf -- "$root"; exit 1
end
set -lx LOCK_READY "$root/lock-ready"
flock -x "$XDG_RUNTIME_DIR/beeper-provision-lock" sh -c 'touch "$LOCK_READY"; sleep 7' &
set -l lock_pid $last_pid
for attempt in (seq 100)
    test -f "$LOCK_READY"; and break
    sleep 0.05
end
if not test -f "$LOCK_READY"
    echo 'FAIL: lock fixture failed to start'
    wait $lock_pid
    rm -rf -- "$root"; exit 1
end
fish --private "$project/beeperctl.fish" update >/dev/null 2>&1
if test $status -eq 0; or not cmp -s "$root/current" "$app"
    echo 'FAIL: concurrent update must time out without changing current'
    wait $lock_pid
    rm -rf -- "$root"; exit 1
end
wait $lock_pid
fish --private "$project/beeperctl.fish" rollback >/dev/null
if test $status -ne 0; or not cmp -s "$FIXTURE" "$app"
    echo 'FAIL: released lock must not block a later operation'
    rm -rf -- "$root"; exit 1
end
set -lx LOCK_DIRECTORY "$XDG_RUNTIME_DIR/beeper-provision-lock"
set -lx LOCK_OWNER_FILE "$root/dead-lock-owner"
set -lx DEAD_LOCK_READY "$root/dead-lock-ready"
printf '%s\n' '#!/bin/sh' 'exec 9<"$LOCK_DIRECTORY"' 'flock -x 9' 'echo $$ > "$LOCK_OWNER_FILE"' 'touch "$DEAD_LOCK_READY"' 'exec sleep 30' > "$root/locker.sh"
chmod +x "$root/locker.sh"
"$root/locker.sh" &
set -l dead_lock_job $last_pid
for attempt in (seq 100)
    test -f "$DEAD_LOCK_READY"; and break
    sleep 0.05
end
if not test -f "$DEAD_LOCK_READY"
    kill -KILL "$dead_lock_job" 2>/dev/null
    wait $dead_lock_job 2>/dev/null
    echo 'FAIL: stale-lock fixture failed to acquire lock'
    rm -rf -- "$root"; exit 1
end
set -l dead_lock_owner (string collect < "$LOCK_OWNER_FILE")
kill -KILL "$dead_lock_owner" 2>/dev/null
wait $dead_lock_job 2>/dev/null
fish --private "$project/beeperctl.fish" update >/dev/null
if test $status -ne 0; or not cmp -s "$FIXTURE" "$app"
    echo 'FAIL: a dead lock owner must release the kernel lock for the next updater'
    rm -rf -- "$root"; exit 1
end
cp "$app.prev" "$root/rollback-before-repair"
set -l rollback_url (string collect < "$XDG_STATE_HOME/beeper-provision/previous-url")
truncate -s 0 "$app"
fish --private "$project/beeperctl.fish" update >/dev/null
if test $status -ne 0; or not cmp -s "$FIXTURE" "$app"; or not cmp -s "$root/rollback-before-repair" "$app.prev"; or test (string collect < "$XDG_STATE_HOME/beeper-provision/previous-url") != "$rollback_url"
    echo 'FAIL: unchanged URL must repair a corrupt current build without replacing a valid rollback'
    rm -rf -- "$root"; exit 1
end
set -l current_hash (sha256sum "$app" | string split -f1 ' ')
set -l previous_hash (sha256sum "$app.prev" | string split -f1 ' ')
printf '%s\n' "$current_hash" "$previous_hash" "$BUILD_URL" "$rollback_url" "$previous_hash" "$rollback_url" > "$XDG_STATE_HOME/beeper-provision/transaction"
set -lx FAIL_RECOVERY_CHECK 1
set -lx FAIL_RESOLVE 1
fish --private "$project/beeperctl.fish" update >/dev/null 2>&1
if test $status -eq 0; or not test -f "$RECOVERY_MARK"; or not cmp -s "$root/rollback-before-repair" "$app"; or test -e "$XDG_STATE_HOME/beeper-provision/transaction"; or test (string collect < "$XDG_STATE_HOME/beeper-provision/current-url") != "$rollback_url"
    echo 'FAIL: recovery must validate an interrupted new binary and restore the prior build on failure'
    rm -rf -- "$root"; exit 1
end
rm -rf -- "$root"
echo 'PASS: install, update, failures, recovery, cleanup, rollback, locking, repair (15 cases)'
