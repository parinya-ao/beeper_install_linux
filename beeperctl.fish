#!/usr/bin/env fish
# Managed-by: beeper-provision

function beeper_architecture
    switch (uname -m)
        case x86_64 amd64
            echo x64
        case aarch64 arm64
            echo arm64
        case '*'
            echo 'Unsupported architecture' >&2
            return 1
    end
end

function beeper_atomic_write --argument-names target
    set -l temporary (mktemp (dirname -- "$target")/.meta.XXXXXXXX); or return 1
    if not printf '%s\n' $argv[2..-1] > "$temporary"; or not mv -f -- "$temporary" "$target"
        rm -f -- "$temporary"
        return 1
    end
end

function beeper_hash --argument-names file
    sha256sum -- "$file" | string split -f1 ' '
end

function beeper_reconcile --argument-names app_dir state_dir
    set -l marker "$state_dir/transaction"
    if not test -e "$marker"; and not test -L "$marker"
        return 0
    end
    if test -L "$marker"; or not test -f "$marker"
        echo 'Unsafe transaction marker' >&2; return 1
    end
    set -l fields (cat -- "$marker")
    if test (count $fields) -ne 6; or not string match -rq '^[0-9a-f]{64}$' -- "$fields[1]"; or not string match -rq '^(-|[0-9a-f]{64})$' -- "$fields[2]"; or not string match -rq '^(-|[0-9a-f]{64})$' -- "$fields[5]"
        echo 'Invalid transaction marker' >&2; return 1
    end
    set -l current "$app_dir/Beeper.AppImage"
    set -l previous "$current.prev"
    if test -L "$current"; or test -L "$previous"
        echo 'Unsafe binary symlink during recovery' >&2; return 1
    end
    set -l current_hash -
    set -l previous_hash -
    if test -f "$current"; set current_hash (beeper_hash "$current"); or return 1; end
    if test -f "$previous"; set previous_hash (beeper_hash "$previous"); or return 1; end
    set -l current_url
    set -l previous_url -
    if test "$current_hash" = "$fields[1]"
        if not fish --private (status filename) validate-candidate "$current" >/dev/null 2>&1
            if test "$fields[2]" != -; and not fish --private (status filename) validate-candidate "$previous" >/dev/null 2>&1
                echo 'Recovery cannot validate either current or previous build' >&2; return 1
            end
            echo 'Interrupted candidate failed validation; restoring the previous state' >&2
            beeper_restore "$app_dir" "$state_dir" "$fields[2]"
            return $status
        end
        set current_url "$fields[3]"
        if test "$fields[2]" != -; and test "$previous_hash" = "$fields[2]"
            set previous_url "$fields[4]"
        else if test "$fields[2]" != -
            echo 'Previous binary does not match transaction marker' >&2; return 1
        else if test "$previous_hash" = "$fields[5]"; and test "$previous_hash" != -
            set previous_url "$fields[6]"
        else if test "$previous_hash" != -
            echo 'Unexpected rollback binary during recovery' >&2; return 1
        end
    else if test "$current_hash" = "$fields[2]"
        set current_url "$fields[4]"
        if test "$previous_hash" = "$fields[2]"; and test "$previous_hash" != -
            set previous_url "$fields[4]"
        else if test "$previous_hash" = "$fields[5]"; and test "$previous_hash" != -
            set previous_url "$fields[6]"
        else if test "$previous_hash" != -
            echo 'Unexpected rollback binary during recovery' >&2; return 1
        end
    else
        echo 'Current binary does not match transaction marker' >&2; return 1
    end
    if test "$current_url" = -
        rm -f -- "$state_dir/current-url"; or return 1
    else
        beeper_atomic_write "$state_dir/current-url" "$current_url"; or return 1
    end
    if test "$previous_url" = -
        rm -f -- "$state_dir/previous-url"; or return 1
    else
        beeper_atomic_write "$state_dir/previous-url" "$previous_url"; or return 1
    end
    rm -f -- "$marker"
end

function beeper_validate_paths
    if not string match -rq '^/' -- "$HOME"; or string match -rq '(^|/)\.\.(/|$)' -- "$HOME"
        echo 'Unsafe HOME' >&2; return 1
    end
    set -l home (realpath -m -- "$HOME")
    if test "$home" = /; or test ! -d "$home"
        echo 'Unsafe or missing HOME' >&2; return 1
    end
    set -l data "$XDG_DATA_HOME"
    set -l config "$XDG_CONFIG_HOME"
    set -l state "$XDG_STATE_HOME"
    set -l cache "$XDG_CACHE_HOME"
    test -n "$data"; or set data "$HOME/.local/share"
    test -n "$config"; or set config "$HOME/.config"
    test -n "$state"; or set state "$HOME/.local/state"
    test -n "$cache"; or set cache "$HOME/.cache"
    for root in "$data" "$config" "$state" "$cache" $XDG_RUNTIME_DIR
        if not string match -rq '^/' -- "$root"; or string match -rq '(^|/)\.\.(/|$)' -- "$root"
            echo 'Unsafe XDG root' >&2; return 1
        end
        set -l resolved (realpath -m -- "$root")
        if test "$resolved" = /; or test "$resolved" = "$home"
            echo 'Unsafe XDG root' >&2; return 1
        end
    end
    set -l roots "$home" "$home" "$data" "$data" "$state" "$cache" "$config" "$config" "$config"
    set -l suffixes .local/opt/beeper .local/bin/beeperctl applications/beeper.desktop beeper-provision beeper-provision beeper-provision systemd/user/beeper-update.service systemd/user/beeper-update.timer systemd/user/timers.target.wants
    for i in (seq (count $roots))
        set -l resolved_root (realpath -m -- "$roots[$i]")
        set -l actual (realpath -m -- "$roots[$i]/$suffixes[$i]")
        if test "$actual" != "$resolved_root/$suffixes[$i]"
            echo "Unsafe symlink in owned path: $roots[$i]/$suffixes[$i]" >&2; return 1
        end
    end
    set -l link "$config/systemd/user/timers.target.wants/beeper-update.timer"
    if test -L "$link"; and test (realpath -m -- "$link") != (realpath -m -- "$config/systemd/user/beeper-update.timer")
        echo 'Unsafe timer enablement symlink' >&2; return 1
    end
end

function beeper_systemd_exec --argument-names manager
    set -l slash '\\'
    set -l escaped (string replace -a -- "$slash" "$slash$slash" "$manager")
    set escaped (string replace -a -- '"' "$slash"'"' "$escaped")
    set escaped (string replace -a -- '%' '%%' "$escaped")
    printf 'ExecStart=:"%s" update --non-interactive\n' "$escaped"
end

function beeper_desktop_lines --argument-names app
    set -l slash '\\'
    set -l exec_path (string replace -a -- "$slash" "$slash$slash$slash$slash" "$app")
    set exec_path (string replace -a -- '"' "$slash$slash"'"' "$exec_path")
    set exec_path (string replace -a -- '$' "$slash$slash"'$' "$exec_path")
    set exec_path (string replace -a -- '`' "$slash$slash"'`' "$exec_path")
    set exec_path (string replace -a -- '%' '%%' "$exec_path")
    set -l try_path (string replace -a -- "$slash" "$slash$slash" "$app")
    if string match -q '*=*' -- "$app"
        set -l script 'exec "$0" "$@"'
        set script (string replace -a -- "$slash" "$slash$slash$slash$slash" "$script")
        set script (string replace -a -- '"' "$slash$slash"'"' "$script")
        set script (string replace -a -- '$' "$slash$slash"'$' "$script")
        printf 'Exec=/bin/sh -c "%s" "%s" %%U\n' "$script" "$exec_path"
    else if string match -q '*%*' -- "$app"
        printf 'Exec=%s "%s" %%U\n' (command -s env) "$exec_path"
    else
        printf 'Exec="%s" %%U\n' "$exec_path"
    end
    printf 'TryExec=%s\n' "$try_path"
end

function beeper_icon --argument-names app data cache
    set -l cache_dir "$cache/beeper-provision"
    set -l icon_dir "$data/beeper-provision"
    for dir in "$cache_dir" "$icon_dir"
        if test -e "$dir"; and begin; not test -d "$dir"; or not test -O "$dir"; or test -L "$dir/.beeper-provision-owned"; or not test -f "$dir/.beeper-provision-owned"; end
            echo applications-internet; return
        end
    end
    if test -L "$icon_dir/icon.png"; or string match -rq '[\x00-\x1f\x7f]' -- "$icon_dir"
        echo applications-internet; return
    end
    if not test -d "$cache_dir"
        mkdir -p -m 700 -- "$cache_dir"; and printf 'beeper-provision\n' > "$cache_dir/.beeper-provision-owned"; or begin; echo applications-internet; return; end
    end
    set -l work (mktemp -d "$cache_dir/icon.XXXXXXXX"); or begin; echo applications-internet; return; end
    set -l relative 'usr/share/icons/hicolor/512x512/apps/beepertexts.png'
    fish --private -c 'cd "$argv[1]"; or exit 1; timeout 45s "$argv[2]" --appimage-extract "$argv[3]" >/dev/null 2>&1' -- "$work" "$app" "$relative"
    set -l extracted "$work/squashfs-root/$relative"
    set -l icon applications-internet
    if not test -f "$extracted"; or test -L "$extracted"
        set -l official_url 'https://www.beeper.com/wp-content/uploads/2026/05/beeper-favicon.png'
        if command -sq curl
            set -l official_icon (mktemp "$work/.official-icon.XXXXXXXX")
            if test -n "$official_icon"
                set -l final (curl --fail --silent --show-error --location --retry 1 --connect-timeout 10 --max-time 30 --proto '=https' --proto-redir '=https' --output "$official_icon" --write-out '%{url_effective}' "$official_url" 2>/dev/null)
                set -l curl_status $status
                set -l size (stat -c %s -- "$official_icon" 2>/dev/null)
                if test $curl_status -eq 0; and test "$final" = "$official_url"; and test "$size" -gt 8; and test "$size" -le 1048576; and test (od -An -tx1 -N8 -- "$official_icon" | string replace -ar '[[:space:]]' '') = 89504e470d0a1a0a
                    set extracted "$official_icon"
                end
            end
        end
    end
    if test -f "$extracted"; and not test -L "$extracted"; and test (realpath -m -- "$extracted") = "$extracted"; and test (od -An -tx1 -N8 -- "$extracted" | string replace -ar '\s' '') = 89504e470d0a1a0a
        if test -d "$icon_dir"; or begin; mkdir -p -m 700 -- "$icon_dir"; and printf 'beeper-provision\n' > "$icon_dir/.beeper-provision-owned"; end
            set -l staged (mktemp "$icon_dir/.icon.XXXXXXXX")
            if test -n "$staged"
                if cp -- "$extracted" "$staged"; and mv -f -- "$staged" "$icon_dir/icon.png"
                    set icon "$icon_dir/icon.png"
                else
                    rm -f -- "$staged"
                end
            end
        end
    end
    rm -rf -- "$work"
    echo "$icon"
end

function beeper_cleanup_stale --argument-names app_dir state_dir cache_dir
    for dir in "$app_dir" "$state_dir" "$cache_dir"
        if not test -d "$dir"; continue; end
        if test -L "$dir"; or not test -O "$dir"; or test -L "$dir/.beeper-provision-owned"; or not test -f "$dir/.beeper-provision-owned"
            echo "Refusing unrelated temporary directory: $dir" >&2; return 1
        end
        set -l entries (find "$dir" -mindepth 1 -maxdepth 1 -print0 | string split0)
        for entry in $entries
            set -l name (path basename -- "$entry")
            set -l temporary 0
            if test "$dir" = "$app_dir"; and string match -rq '^\.(candidate|previous|restore)\.[[:alnum:]]{8}$' -- "$name"
                set temporary 1
            else if test "$dir" = "$state_dir"; and string match -rq '^\.meta\.[[:alnum:]]{8}$' -- "$name"
                set temporary 1
            else if test "$dir" = "$cache_dir"; and string match -rq '^(candidate|icon)\.[[:alnum:]]{8}$' -- "$name"
                set temporary 1
            end
            if test $temporary -eq 0; continue; end
            if test -L "$entry"; or not test -O "$entry"
                echo "Refusing unsafe temporary file: $entry" >&2; return 1
            end
            if test -d "$entry"; and test "$dir" = "$cache_dir"; and string match -q 'icon.*' -- "$name"
                rm -rf -- "$entry"; or return 1
            else if test -f "$entry"
                rm -f -- "$entry"; or return 1
            else
                echo "Refusing unexpected temporary entry: $entry" >&2; return 1
            end
        end
    end
end

function beeper_restore --argument-names app_dir state_dir old_hash
    set -l current "$app_dir/Beeper.AppImage"
    if test "$old_hash" = -
        rm -f -- "$current"; or return 1
    else
        if not test -f "$current.prev"; or test (beeper_hash "$current.prev") != "$old_hash"
            return 1
        end
        set -l restore (mktemp "$app_dir/.restore.XXXXXXXX"); or return 1
        rm -f -- "$restore"
        if not begin; ln -- "$current.prev" "$restore"; or cp -p -- "$current.prev" "$restore"; end; or not mv -f -- "$restore" "$current"
            rm -f -- "$restore"; return 1
        end
    end
    beeper_reconcile "$app_dir" "$state_dir"
end

function beeper_promote --argument-names app_dir state_dir staged url
    set -l current "$app_dir/Beeper.AppImage"
    set -l old_hash -
    set -l old_url -
    set -l previous_hash -
    set -l previous_url -
    if test -f "$current"
        set old_hash (beeper_hash "$current"); or begin; rm -f -- "$staged"; return 1; end
        if test -f "$state_dir/current-url"; set old_url (string collect < "$state_dir/current-url"); end
    end
    if test -f "$current.prev"
        set previous_hash (beeper_hash "$current.prev"); or begin; rm -f -- "$staged"; return 1; end
        if test -f "$state_dir/previous-url"; set previous_url (string collect < "$state_dir/previous-url"); end
    end
    for recorded_url in "$old_url" "$previous_url"
        if test "$recorded_url" != -; and not string match -rq '^https://([a-zA-Z0-9-]+\.)*beeper\.com/[^[:space:]]+$' -- "$recorded_url"
            echo 'Invalid stored build URL' >&2; rm -f -- "$staged"; return 1
        end
    end
    set -l new_hash (beeper_hash "$staged"); or begin; rm -f -- "$staged"; return 1; end
    if test "$new_hash" = "$old_hash"
        beeper_atomic_write "$state_dir/current-url" "$url"; or begin; rm -f -- "$staged"; return 1; end
        rm -f -- "$staged"
        return $status
    end
    set -l prev_staged
    if test "$old_hash" != -; and not begin; test -f "$current.prev"; and test "$current" -ef "$current.prev"; end
        set prev_staged (mktemp "$app_dir/.previous.XXXXXXXX"); or begin; rm -f -- "$staged"; return 1; end
        rm -f -- "$prev_staged"
        if not ln -- "$current" "$prev_staged"; and not cp -p -- "$current" "$prev_staged"
            rm -f -- "$staged" "$prev_staged"; return 1
        end
    end
    if not beeper_atomic_write "$state_dir/transaction" "$new_hash" "$old_hash" "$url" "$old_url" "$previous_hash" "$previous_url"
        rm -f -- "$staged" $prev_staged; return 1
    end
    if test -n "$prev_staged"; and not mv -f -- "$prev_staged" "$current.prev"
        rm -f -- "$staged" "$prev_staged"
        beeper_reconcile "$app_dir" "$state_dir"
        return 1
    end
    if not mv -f -- "$staged" "$current"
        rm -f -- "$staged"
        beeper_reconcile "$app_dir" "$state_dir"
        return 1
    end
    if not fish --private (status filename) validate-candidate "$current"
        beeper_restore "$app_dir" "$state_dir" "$old_hash"; or echo 'Automatic restoration failed; transaction recovery is pending' >&2
        echo 'Installed candidate failed validation' >&2; return 1
    end
    if not beeper_reconcile "$app_dir" "$state_dir"
        beeper_restore "$app_dir" "$state_dir" "$old_hash"; or echo 'Automatic restoration failed; transaction recovery is pending' >&2
        echo 'Promotion failed; transaction recovery may be needed' >&2; return 1
    end
end

function beeper_preflight
    beeper_validate_paths; or return 1
    for cmd in fish curl flock mkdir mktemp cp chmod mv stat od timeout sha256sum realpath ln grep
        if not command -sq "$cmd"
            echo "Required command unavailable: $cmd" >&2; return 1
        end
    end
    set -l data "$XDG_DATA_HOME"; test -n "$data"; or set data "$HOME/.local/share"
    set -l config "$XDG_CONFIG_HOME"; test -n "$config"; or set config "$HOME/.config"
    set -l state "$XDG_STATE_HOME"; test -n "$state"; or set state "$HOME/.local/state"
    set -l cache "$XDG_CACHE_HOME"; test -n "$cache"; or set cache "$HOME/.cache"
    for dir in "$HOME/.local/opt/beeper" "$state/beeper-provision" "$cache/beeper-provision"
        if test -L "$dir"; or begin; test -e "$dir"; and begin; not test -d "$dir"; or not test -O "$dir"; or test -L "$dir/.beeper-provision-owned"; or not test -f "$dir/.beeper-provision-owned"; end; end
            echo "Refusing unrelated directory: $dir" >&2; return 1
        end
    end
    set -l files "$HOME/.local/bin/beeperctl" "$data/applications/beeper.desktop" "$config/systemd/user/beeper-update.service" "$config/systemd/user/beeper-update.timer"
    set -l markers '# Managed-by: beeper-provision' 'X-Beeper-Provision-Managed=true' '# Managed-by: beeper-provision' '# Managed-by: beeper-provision'
    for i in (seq (count $files))
        if test -L "$files[$i]"; or begin; test -e "$files[$i]"; and not grep -Fxq -- "$markers[$i]" "$files[$i]"; end
            echo "Refusing unrelated file: $files[$i]" >&2; return 1
        end
    end
end

function beeper_record_autoupdate --argument-names value
    set -l state "$XDG_STATE_HOME"; test -n "$state"; or set state "$HOME/.local/state"
    set -l dir "$state/beeper-provision"
    if not test -d "$dir"; return 0; end
    if test -L "$dir"; or not test -O "$dir"; or test -L "$dir/.beeper-provision-owned"; or not test -f "$dir/.beeper-provision-owned"; or test -L "$dir/autoupdate-expected"
        echo 'Unsafe automatic-update state' >&2; return 1
    end
    beeper_atomic_write "$dir/autoupdate-expected" "$value"
end

function beeper_report --argument-names result detail
    echo "$result: $detail"
    if test "$result" = FAIL; set -g beeper_doctor_failed 1; end
end

switch "$argv[1]"
    case smoke
        if not test -x "$HOME/.local/opt/beeper/Beeper.AppImage"
            echo 'Beeper AppImage is not executable or not installed' >&2; exit 1
        end
        fish --private (status filename) run >/dev/null 2>&1 &
        set -l pid $last_pid
        sleep 2
        if kill -0 "$pid" 2>/dev/null
            echo "Beeper process $pid is still running; GUI health is not verified"
        else
            wait "$pid" 2>/dev/null
            echo 'Beeper exited during the smoke test' >&2
            exit 1
        end
    case verify
        beeper_preflight; or exit 1
        set -l data "$XDG_DATA_HOME"; test -n "$data"; or set data "$HOME/.local/share"
        set -l config "$XDG_CONFIG_HOME"; test -n "$config"; or set config "$HOME/.config"
        set -l state "$XDG_STATE_HOME"; test -n "$state"; or set state "$HOME/.local/state"
        set -l app "$HOME/.local/opt/beeper/Beeper.AppImage"
        set -l url_file "$state/beeper-provision/current-url"
        set -l manager "$HOME/.local/bin/beeperctl"
        set -l desktop "$data/applications/beeper.desktop"
        if test -e "$state/beeper-provision/transaction"; or test -L "$state/beeper-provision/transaction"
            echo 'FAIL: transaction recovery is pending; run update or rollback' >&2; exit 1
        end
        if test -L "$app"; or not test -x "$app"; or not test -f "$app"; or not test -f "$url_file"; or test -L "$url_file"; or not string match -rq '^https://([a-zA-Z0-9-]+\.)*beeper\.com/[^[:space:]]+$' -- (string collect < "$url_file"); or not test -x "$manager"; or not test -f "$desktop"
            echo 'FAIL: required installation files or metadata' >&2; exit 1
        end
        set -l desktop_lines (beeper_desktop_lines "$app")
        for line in $desktop_lines '[Desktop Entry]' 'Type=Application' 'Name=Beeper' 'Terminal=false' 'Categories=Network;InstantMessaging;Chat;' 'MimeType=x-scheme-handler/beeper;' 'X-Beeper-Provision-Managed=true'
            if not grep -Fxq -- "$line" "$desktop"
                echo "FAIL: desktop entry is missing or changed: $line" >&2; exit 1
            end
        end
        fish --private (status filename) validate-candidate "$app"; or exit 1
        if command -sq desktop-file-validate; and not desktop-file-validate "$desktop"
            exit 1
        end
        set -l expected "$state/beeper-provision/autoupdate-expected"
        if test -L "$expected"; echo 'FAIL: unsafe timer state' >&2; exit 1; end
        if test -f "$expected"; and test (string collect < "$expected") = enabled
            set -l service "$config/systemd/user/beeper-update.service"
            set -l timer "$config/systemd/user/beeper-update.timer"
            if not test -f "$service"; or not test -f "$timer"
                echo 'FAIL: expected timer units missing' >&2; exit 1
            end
            if not grep -Fxq -- (beeper_systemd_exec "$manager") "$service"
                echo 'FAIL: update service command changed' >&2; exit 1
            end
            for line in '[Timer]' 'OnCalendar=daily' 'Persistent=true' 'RandomizedDelaySec=1h' '[Install]' 'WantedBy=timers.target'
                if not grep -Fxq -- "$line" "$timer"
                    echo "FAIL: update timer is missing $line" >&2; exit 1
                end
            end
            systemctl --user is-enabled --quiet beeper-update.timer; or exit 1
            systemctl --user is-active --quiet beeper-update.timer; or exit 1
        end
        echo 'PASS: installation invariants'
    case doctor
        set -g beeper_doctor_failed 0
        if set -l arch (beeper_architecture 2>/dev/null)
            beeper_report PASS "architecture $arch"
        else
            beeper_report FAIL 'architecture unsupported'
        end
        for cmd in fish mise curl
            if command -sq "$cmd"; beeper_report PASS "$cmd available"; else; beeper_report UNKNOWN "$cmd unavailable"; end
        end
        set -l libc (getconf GNU_LIBC_VERSION 2>/dev/null)
        set -l libc_parts (string match -r '([0-9]+)\.([0-9]+)' -- "$libc")
        if test (count $libc_parts) -lt 3
            beeper_report UNKNOWN 'glibc version unavailable'
        else if test "$libc_parts[2]" -gt 2; or begin; test "$libc_parts[2]" -eq 2; and test "$libc_parts[3]" -ge 32; end
            beeper_report PASS "glibc $libc"
        else
            beeper_report FAIL "glibc $libc (requires 2.32+)"
        end
        if beeper_validate_paths >/dev/null 2>&1; beeper_report PASS 'XDG paths'; else; beeper_report FAIL 'XDG paths'; end
        set -l data "$XDG_DATA_HOME"; test -n "$data"; or set data "$HOME/.local/share"
        set -l config "$XDG_CONFIG_HOME"; test -n "$config"; or set config "$HOME/.config"
        set -l state "$XDG_STATE_HOME"; test -n "$state"; or set state "$HOME/.local/state"
        set -l app "$HOME/.local/opt/beeper/Beeper.AppImage"
        if test -f "$app"; and not test -L "$app"; beeper_report PASS 'Beeper installation present'; else; beeper_report FAIL 'Beeper installation missing or unsafe'; end
        if test -x "$app"; and not test -L "$app"; beeper_report PASS 'AppImage executable'; else; beeper_report FAIL 'AppImage executable'; end
        if fish --private (status filename) validate-candidate "$app" >/dev/null 2>&1; beeper_report PASS 'AppImage health'; else; beeper_report FAIL 'AppImage health'; end
        if test -f "$data/applications/beeper.desktop"; and grep -Fxq 'X-Beeper-Provision-Managed=true' "$data/applications/beeper.desktop"; beeper_report PASS 'desktop entry'; else; beeper_report FAIL 'desktop entry'; end
        if test -f "$app.prev"; and not test -L "$app.prev"; beeper_report PASS 'rollback available'; else; beeper_report UNKNOWN 'rollback unavailable'; end
        if test -n "$XDG_RUNTIME_DIR"; and test -d "$XDG_RUNTIME_DIR"; and test -O "$XDG_RUNTIME_DIR"; and not test -L "$XDG_RUNTIME_DIR/beeper-provision-lock"
            if not test -d "$XDG_RUNTIME_DIR/beeper-provision-lock"; or flock --nonblock "$XDG_RUNTIME_DIR/beeper-provision-lock" true
                beeper_report PASS 'lock available'
            else
                beeper_report UNKNOWN 'lock currently held'
            end
        else
            beeper_report UNKNOWN 'lock directory unavailable'
        end
        if command -sq systemctl; and systemctl --user show-environment >/dev/null 2>&1
            beeper_report PASS 'systemd user manager'
            if test -f "$config/systemd/user/beeper-update.service"; beeper_report PASS 'update service'; else; beeper_report UNKNOWN 'update service absent'; end
            if systemctl --user is-enabled --quiet beeper-update.timer; and systemctl --user is-active --quiet beeper-update.timer
                beeper_report PASS 'update timer enabled and active'
            else
                beeper_report UNKNOWN 'update timer disabled or inactive'
            end
        else
            beeper_report UNKNOWN 'systemd user manager unavailable'
            beeper_report UNKNOWN 'update service state'
            beeper_report UNKNOWN 'update timer state'
        end
        set -l latest (fish --private (status filename) resolve-build 2>/dev/null)
        if test $status -eq 0; and test -n "$latest"
            beeper_report PASS 'official endpoint reachable'
            if test -f "$state/beeper-provision/current-url"
                if test (string collect < "$state/beeper-provision/current-url") = "$latest"; beeper_report PASS 'latest build installed'; else; beeper_report FAIL 'newer build available'; end
            else
                beeper_report UNKNOWN 'installed build URL unavailable'
            end
        else
            beeper_report UNKNOWN 'official endpoint unreachable'
            beeper_report UNKNOWN 'latest build comparison'
        end
        if test -c /dev/fuse; and test -r /dev/fuse; and test -w /dev/fuse; beeper_report PASS 'FUSE device accessible'; else; beeper_report UNKNOWN 'FUSE device unavailable'; end
        beeper_report UNKNOWN 'extract-and-run not exercised'
        exit $beeper_doctor_failed
    case provision
        if test (count $argv) -gt 2; or begin; test (count $argv) -eq 2; and test "$argv[2]" != --no-autoupdate; end
            echo 'Usage: beeperctl provision [--no-autoupdate]' >&2; exit 2
        end
        beeper_preflight; or exit 1
        if test "$argv[2]" != --no-autoupdate; and not command -sq systemctl
            echo 'systemctl is required for automatic updates' >&2; exit 1
        end
        if test "$argv[2]" != --no-autoupdate
            systemctl --user show-environment >/dev/null 2>&1; or begin
                echo 'systemd user manager is unavailable for automatic updates' >&2; exit 1
            end
        end
        fish --private (status filename) update; or exit 1
        fish --private (status filename) install-controller; or exit 1
        fish --private (status filename) integrate; or exit 1
        if test "$argv[2]" != --no-autoupdate
            fish --private (status filename) autoupdate enable; or exit 1
        else
            fish --private (status filename) autoupdate disable; or exit 1
        end
        echo 'Beeper provisioning complete'
    case autoupdate
        if test "$argv[2]" = status
            systemctl --user is-enabled beeper-update.timer
            exit $status
        end
        if test "$argv[2]" != enable; and test "$argv[2]" != disable
            echo 'Usage: beeperctl autoupdate enable|disable|status' >&2; exit 2
        end
        beeper_validate_paths; or exit 1
        if test -z "$XDG_RUNTIME_DIR"; or not test -d "$XDG_RUNTIME_DIR"; or not test -O "$XDG_RUNTIME_DIR"
            echo 'A user-owned XDG_RUNTIME_DIR is required' >&2; exit 1
        end
        set -l lock "$XDG_RUNTIME_DIR/beeper-provision-lock"
        if test -L "$lock"; or begin; test -e "$lock"; and not test -d "$lock"; end
            echo 'Unsafe update lock path' >&2; exit 1
        end
        mkdir -p -m 700 -- "$lock"; or exit 1
        if not test -O "$lock"; echo 'Update lock is not user-owned' >&2; exit 1; end
        env BEEPER_LOCKED=1 flock --exclusive --timeout 5 -- "$lock" fish --private (status filename) __autoupdate_locked "$argv[2]"
        exit $status
    case __autoupdate_locked
        if test "$BEEPER_LOCKED" != 1
            echo 'Internal command requires update lock' >&2; exit 1
        end
        beeper_validate_paths; or exit 1
        set -l config "$XDG_CONFIG_HOME"; test -n "$config"; or set config "$HOME/.config"
        set -l units "$config/systemd/user"
        set -l service "$units/beeper-update.service"
        set -l timer "$units/beeper-update.timer"
        for file in "$service" "$timer"
            if test -L "$file"; or begin; test -e "$file"; and not grep -Fxq '# Managed-by: beeper-provision' -- "$file"; end
                echo "Refusing unrelated systemd unit: $file" >&2; exit 1
            end
        end
        if test "$argv[2]" = disable
            if test -e "$timer"; or test -L "$units/timers.target.wants/beeper-update.timer"
                systemctl --user disable --now beeper-update.timer; or exit 1
            end
            beeper_record_autoupdate disabled; or exit 1
            exit 0
        end
        set -l manager "$HOME/.local/bin/beeperctl"
        if test -L "$manager"; or not test -x "$manager"; or not grep -Fxq '# Managed-by: beeper-provision' -- "$manager"
            echo 'Install the managed controller before enabling updates' >&2; exit 1
        end
        if string match -rq '[\x00-\x1f\x7f]' -- "$manager"
            echo 'Systemd executable path contains a control character' >&2; exit 1
        end
        mkdir -p -- "$units"; or exit 1
        set -l slash '\\'
        set -l temp (mktemp "$units/.beeper-service.XXXXXXXX"); or exit 1
        printf '%s\n' '# Managed-by: beeper-provision' '[Unit]' 'Description=Update Beeper AppImage' '[Service]' 'Type=oneshot' > "$temp"
        for variable in HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_RUNTIME_DIR
            set -l value $$variable
            if test -z "$value"; continue; end
            if string match -rq '[\x00-\x1f\x7f]' -- "$value"
                rm -f -- "$temp"; echo 'Systemd environment path contains a control character' >&2; exit 1
            end
            set value (string replace -a -- "$slash" "$slash$slash" "$value")
            set value (string replace -a -- '"' "$slash"'"' "$value")
            set value (string replace -a -- '%' '%%' "$value")
            printf 'Environment="%s=%s"\n' "$variable" "$value" >> "$temp"
        end
        beeper_systemd_exec "$manager" >> "$temp"
        if not mv -f -- "$temp" "$service"; rm -f -- "$temp"; exit 1; end
        set temp (mktemp "$units/.beeper-timer.XXXXXXXX"); or exit 1
        printf '%s\n' '# Managed-by: beeper-provision' '[Unit]' 'Description=Daily Beeper AppImage update' '[Timer]' 'OnCalendar=daily' 'Persistent=true' 'RandomizedDelaySec=1h' '[Install]' 'WantedBy=timers.target' > "$temp"
        if not mv -f -- "$temp" "$timer"; rm -f -- "$temp"; exit 1; end
        beeper_record_autoupdate enabled; or exit 1
        systemctl --user daemon-reload; or exit 1
        systemctl --user enable --now beeper-update.timer; or exit 1
        systemctl --user is-enabled --quiet beeper-update.timer; or exit 1
        systemctl --user is-active --quiet beeper-update.timer; or exit 1
        echo 'Automatic updates enabled'
    case update rollback integrate install-controller uninstall purge
        if test "$argv[1]" = purge; and begin; test (count $argv) -ne 2; or test "$argv[2]" != --user-data; end
            echo 'Usage: beeperctl purge --user-data' >&2; exit 2
        end
        beeper_validate_paths; or exit 1
        if test -z "$XDG_RUNTIME_DIR"; or not test -d "$XDG_RUNTIME_DIR"; or not test -O "$XDG_RUNTIME_DIR"
            echo 'A user-owned XDG_RUNTIME_DIR is required for updates' >&2; exit 1
        end
        set -l lock "$XDG_RUNTIME_DIR/beeper-provision-lock"
        if test -L "$lock"; or begin; test -e "$lock"; and not test -d "$lock"; end
            echo 'Unsafe update lock path' >&2; exit 1
        end
        mkdir -p -m 700 -- "$lock"; or exit 1
        if not test -O "$lock"
            echo 'Update lock is not owned by this user' >&2; exit 1
        end
        set -l operation "__$argv[1]"_locked
        if test "$argv[1]" = update; set operation __update_logged; end
        env BEEPER_LOCKED=1 flock --exclusive --timeout 5 -- "$lock" fish --private (status filename) "$operation" $argv[2..-1]
        exit $status
    case __purge_locked
        if test "$BEEPER_LOCKED" != 1; or test "$argv[2]" != --user-data; or test (count $argv) -ne 2
            echo 'Purge requires --user-data and the lifecycle lock' >&2; exit 1
        end
        beeper_validate_paths; or exit 1
        for cmd in pgrep find mountpoint realpath id
            if not command -sq "$cmd"; echo "Purge safety check unavailable: $cmd" >&2; exit 1; end
        end
        pgrep -u (id -u) -ix 'beepertexts|beeper|beeper-desktop' >/dev/null 2>&1
        set -l process_status $status
        if test $process_status -eq 0
            echo 'Close Beeper before purging its profile' >&2; exit 1
        else if test $process_status -ne 1
            echo 'Could not determine whether Beeper is running' >&2; exit 1
        end
        set -l config "$XDG_CONFIG_HOME"; test -n "$config"; or set config "$HOME/.config"
        if string match -rq '[\x00-\x1f\x7f]' -- "$config"
            echo 'Unsafe profile path' >&2; exit 1
        end
        set -l root (realpath -m -- "$config"); or exit 1
        set -l target "$config/BeeperTexts"
        if test -L "$target"; or test (realpath -m -- "$target") != "$root/BeeperTexts"
            echo 'Refusing profile symlink escape' >&2; exit 1
        end
        if not test -e "$target"
            echo 'Observed BeeperTexts profile is absent'; exit 0
        end
        if not test -d "$target"; or not test -O "$target"
            echo 'Refusing a profile that is not a user-owned directory' >&2; exit 1
        end
        set -l unsafe (find "$target" -xdev \( -type l -o ! -uid (id -u) \) -print -quit); or exit 1
        if test -n "$unsafe"
            echo 'Refusing profile containing a symlink or another owner' >&2; exit 1
        end
        set -l mounted (find "$target" -xdev -type d -exec mountpoint -q '{}' \; -print -quit); or exit 1
        if test -n "$mounted"
            echo 'Refusing profile containing a mount point' >&2; exit 1
        end
        rm -rf -- "$target"; or exit 1
        echo 'Removed the observed BeeperTexts profile; other historical profile locations were not removed'
    case __update_logged
        if test "$BEEPER_LOCKED" != 1
            echo 'Internal command requires update lock' >&2; exit 1
        end
        fish --private (status filename) __update_locked
        set -l result $status
        set -l state "$XDG_STATE_HOME"; test -n "$state"; or set state "$HOME/.local/state"
        set -l dir "$state/beeper-provision"
        if test -d "$dir"; and test -O "$dir"; and not test -L "$dir"; and not test -L "$dir/.beeper-provision-owned"; and test -f "$dir/.beeper-provision-owned"
            set -l outcome success
            if test $result -ne 0; set outcome failed; end
            set -l timestamp (date -u '+%Y-%m-%dT%H:%M:%SZ')
            if test -L "$dir/last-update"; or not beeper_atomic_write "$dir/last-update" "$timestamp $outcome (exit $result)"
                echo 'Could not record update result' >&2
                if test $result -eq 0; set result 1; end
            end
        end
        exit $result
    case __uninstall_locked
        if test "$BEEPER_LOCKED" != 1
            echo 'Internal command requires update lock' >&2; exit 1
        end
        beeper_preflight; or exit 1
        set -l data "$XDG_DATA_HOME"; test -n "$data"; or set data "$HOME/.local/share"
        set -l config "$XDG_CONFIG_HOME"; test -n "$config"; or set config "$HOME/.config"
        set -l state "$XDG_STATE_HOME"; test -n "$state"; or set state "$HOME/.local/state"
        set -l cache "$XDG_CACHE_HOME"; test -n "$cache"; or set cache "$HOME/.cache"
        set -l app_dir "$HOME/.local/opt/beeper"
        set -l state_dir "$state/beeper-provision"
        set -l cache_dir "$cache/beeper-provision"
        set -l icon_dir "$data/beeper-provision"
        set -l owned_dirs "$app_dir" "$state_dir" "$cache_dir"
        if test -d "$icon_dir"; and test -O "$icon_dir"; and not test -L "$icon_dir/.beeper-provision-owned"; and test -f "$icon_dir/.beeper-provision-owned"
            set -a owned_dirs "$icon_dir"
        end
        for dir in $owned_dirs
            if not test -d "$dir"; continue; end
            set -l entries (find "$dir" -mindepth 1 -maxdepth 1 -print0 | string split0)
            for entry in $entries
                if test -L "$entry"; or not test -f "$entry"; or not test -O "$entry"
                    echo "Refusing unsafe owned-directory entry: $entry" >&2; exit 1
                end
                set -l name (path basename -- "$entry")
                switch "$dir:$name"
                    case "$app_dir:"'.beeper-provision-owned' "$app_dir:"'Beeper.AppImage' "$app_dir:"'Beeper.AppImage.prev' "$app_dir:"'.candidate.*' "$app_dir:"'.previous.*' "$app_dir:"'.restore.*' "$state_dir:"'.beeper-provision-owned' "$state_dir:"'current-url' "$state_dir:"'previous-url' "$state_dir:"'transaction' "$state_dir:"'last-update' "$state_dir:"'autoupdate-expected' "$state_dir:"'.meta.*' "$cache_dir:"'.beeper-provision-owned' "$cache_dir:"'candidate.*' "$icon_dir:"'.beeper-provision-owned' "$icon_dir:"'icon.png' "$icon_dir:"'.icon.*'
                    case '*'
                        echo "Refusing unexpected owned-directory entry: $entry" >&2; exit 1
                end
            end
        end
        set -l units "$config/systemd/user"
        set -l service "$units/beeper-update.service"
        set -l timer "$units/beeper-update.timer"
        set -l enabled "$units/timers.target.wants/beeper-update.timer"
        if test -e "$service"; or test -e "$timer"; or test -L "$enabled"
            systemctl --user disable --now beeper-update.timer; or exit 1
            rm -f -- "$enabled" "$service" "$timer"; or exit 1
            systemctl --user daemon-reload; or exit 1
        end
        rm -f -- "$data/applications/beeper.desktop"; or exit 1
        for dir in $owned_dirs
            if not test -d "$dir"; continue; end
            set -l entries (find "$dir" -mindepth 1 -maxdepth 1 -print0 | string split0)
            if test (count $entries) -gt 0
                rm -f -- $entries; or exit 1
            end
            rmdir -- "$dir"; or exit 1
        end
        rm -f -- "$HOME/.local/bin/beeperctl"; or exit 1
        if command -sq update-desktop-database; and test -d "$data/applications"
            update-desktop-database "$data/applications" >/dev/null 2>&1; or echo 'Desktop database update failed' >&2
        end
        echo 'Beeper provisioning removed; user data preserved'
    case __install-controller_locked
        if test "$BEEPER_LOCKED" != 1
            echo 'Internal command requires update lock' >&2; exit 1
        end
        beeper_validate_paths; or exit 1
        set -l bin "$HOME/.local/bin"
        set -l manager "$bin/beeperctl"
        if test -L "$manager"; or begin; test -e "$manager"; and not grep -Fxq '# Managed-by: beeper-provision' -- "$manager"; end
            echo "Refusing unrelated controller: $manager" >&2; exit 1
        end
        mkdir -p -- "$bin"; or exit 1
        set -l temp (mktemp "$bin/.beeperctl.XXXXXXXX"); or exit 1
        if not cp -- (status filename) "$temp"; or not chmod 700 -- "$temp"; or not mv -f -- "$temp" "$manager"
            rm -f -- "$temp"; exit 1
        end
        echo "Controller: $manager"
    case __integrate_locked
        if test "$BEEPER_LOCKED" != 1
            echo 'Internal command requires update lock' >&2; exit 1
        end
        beeper_validate_paths; or exit 1
        set -l app_dir "$HOME/.local/opt/beeper"
        set -l app "$app_dir/Beeper.AppImage"
        if not test -O "$app_dir"; or test -L "$app_dir/.beeper-provision-owned"; or not test -f "$app_dir/.beeper-provision-owned"; or test -L "$app"; or not test -x "$app"
            echo 'A manager-owned executable is required' >&2; exit 1
        end
        if string match -rq '[\x00-\x1f\x7f]' -- "$app"
            echo 'Desktop executable path contains an unsupported character' >&2; exit 1
        end
        set -l data "$XDG_DATA_HOME"; test -n "$data"; or set data "$HOME/.local/share"
        set -l cache "$XDG_CACHE_HOME"; test -n "$cache"; or set cache "$HOME/.cache"
        set -l applications "$data/applications"
        set -l desktop "$applications/beeper.desktop"
        if test -L "$desktop"; or begin; test -e "$desktop"; and not grep -Fxq 'X-Beeper-Provision-Managed=true' -- "$desktop"; end
            echo "Refusing unrelated desktop entry: $desktop" >&2; exit 1
        end
        mkdir -p -- "$applications"; or exit 1
        set -l slash '\\'
        set -l icon (beeper_icon "$app" "$data" "$cache")
        set icon (string replace -a -- "$slash" "$slash$slash" "$icon")
        set -l temp (mktemp --suffix=.desktop "$applications/.beeper.XXXXXXXX"); or exit 1
        printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Beeper' 'GenericName=Chat Client' > "$temp"
        beeper_desktop_lines "$app" >> "$temp"
        printf 'Icon=%s\n' "$icon" >> "$temp"
        printf '%s\n' 'Terminal=false' 'Categories=Network;InstantMessaging;Chat;' 'StartupNotify=true' 'StartupWMClass=Beeper' 'MimeType=x-scheme-handler/beeper;' 'X-Beeper-Provision-Managed=true' >> "$temp"
        if command -sq desktop-file-validate; and not desktop-file-validate "$temp"
            rm -f -- "$temp"; exit 1
        end
        if not mv -f -- "$temp" "$desktop"
            rm -f -- "$temp"; exit 1
        end
        if command -sq update-desktop-database
            update-desktop-database "$applications" >/dev/null 2>&1; or echo 'Desktop database update failed' >&2
        end
        echo "Desktop entry: $desktop"
    case __rollback_locked
        if test "$BEEPER_LOCKED" != 1
            echo 'Internal command requires update lock' >&2; exit 1
        end
        beeper_validate_paths; or exit 1
        set -l state "$XDG_STATE_HOME"; test -n "$state"; or set state "$HOME/.local/state"
        set -l state_dir "$state/beeper-provision"
        set -l app_dir "$HOME/.local/opt/beeper"
        for dir in "$state_dir" "$app_dir"
            if not test -d "$dir"; or not test -O "$dir"; or test -L "$dir/.beeper-provision-owned"; or not test -f "$dir/.beeper-provision-owned"
                echo "Refusing unrelated directory: $dir" >&2; exit 1
            end
        end
        beeper_reconcile "$app_dir" "$state_dir"; or exit 1
        set -l cache "$XDG_CACHE_HOME"; test -n "$cache"; or set cache "$HOME/.cache"
        beeper_cleanup_stale "$app_dir" "$state_dir" "$cache/beeper-provision"; or exit 1
        set -l current "$app_dir/Beeper.AppImage"
        for file in "$current" "$current.prev" "$state_dir/current-url" "$state_dir/previous-url"
            if test -L "$file"; or not test -f "$file"
                echo "Rollback requires safe current and previous files: $file" >&2; exit 1
            end
        end
        if test (beeper_hash "$current") = (beeper_hash "$current.prev")
            echo 'Rollback contains the current build' >&2; exit 1
        end
        fish --private (status filename) validate-candidate "$current.prev"; or exit 1
        set -l url (string collect < "$state_dir/previous-url")
        set -l staged (mktemp "$app_dir/.candidate.XXXXXXXX"); or exit 1
        rm -f -- "$staged"
        if not ln -- "$current.prev" "$staged"; and not cp -p -- "$current.prev" "$staged"
            rm -f -- "$staged"; exit 1
        end
        beeper_promote "$app_dir" "$state_dir" "$staged" "$url"; or exit 1
        echo "Rolled back to $url"
    case __update_locked
        if test "$BEEPER_LOCKED" != 1
            echo 'Internal command requires update lock' >&2; exit 1
        end
        beeper_validate_paths; or exit 1
        set -l state "$XDG_STATE_HOME"; test -n "$state"; or set state "$HOME/.local/state"
        set -l cache "$XDG_CACHE_HOME"; test -n "$cache"; or set cache "$HOME/.cache"
        set -l state_dir "$state/beeper-provision"
        set -l cache_dir "$cache/beeper-provision"
        set -l app_dir "$HOME/.local/opt/beeper"
        for dir in "$state_dir" "$cache_dir" "$app_dir"
            if test -e "$dir"
                if not test -d "$dir"; or not test -O "$dir"; or test -L "$dir/.beeper-provision-owned"; or not test -f "$dir/.beeper-provision-owned"
                    echo "Refusing unrelated directory: $dir" >&2; exit 1
                end
            end
        end
        beeper_reconcile "$app_dir" "$state_dir"; or exit 1
        beeper_cleanup_stale "$app_dir" "$state_dir" "$cache_dir"; or exit 1
        for file in "$app_dir/Beeper.AppImage" "$app_dir/Beeper.AppImage.prev" "$state_dir/current-url" "$state_dir/previous-url"
            if test -L "$file"; or begin; test -e "$file"; and not test -f "$file"; end
                echo "Unsafe owned file: $file" >&2; exit 1
            end
        end
        set -l url (fish --private (status filename) resolve-build); or exit 1
        set -l current "$app_dir/Beeper.AppImage"
        set -l current_healthy 0
        if test -f "$current"
            if fish --private (status filename) validate-candidate "$current" >/dev/null 2>&1
                set current_healthy 1
            else if test -f "$current.prev"; and fish --private (status filename) validate-candidate "$current.prev" >/dev/null 2>&1
                echo 'Current build is unhealthy; restoring the previous build' >&2
                fish --private (status filename) __rollback_locked; or exit 1
                set current_healthy 1
            end
        end
        if test $current_healthy -eq 1; and test -f "$state_dir/current-url"; and not test -L "$state_dir/current-url"; and test (string collect < "$state_dir/current-url") = "$url"
            echo 'Already up to date'; exit 0
        end
        for dir in "$state_dir" "$cache_dir" "$app_dir"
            if not test -d "$dir"
                mkdir -p -m 700 -- "$dir"; or exit 1
                printf 'beeper-provision\n' > "$dir/.beeper-provision-owned"; or exit 1
            end
        end
        set -l download (mktemp "$cache_dir/candidate.XXXXXXXX"); or exit 1
        set -l final (curl --fail --silent --show-error --location --retry 2 --connect-timeout 15 --max-time 600 --proto '=https' --proto-redir '=https' --output "$download" --write-out '%{url_effective}' "$url")
        set -l curl_status $status
        if test $curl_status -ne 0; or test "$final" != "$url"
            rm -f -- "$download"
            echo 'Download failed or changed its resolved URL' >&2; exit 1
        end
        chmod 700 -- "$download"; or begin; rm -f -- "$download"; exit 1; end
        if not fish --private (status filename) validate-candidate "$download"
            rm -f -- "$download"; exit 1
        end
        set -l staged (mktemp "$app_dir/.candidate.XXXXXXXX"); or begin; rm -f -- "$download"; exit 1; end
        if not cp -- "$download" "$staged"; or not chmod 700 -- "$staged"
            rm -f -- "$download" "$staged"; exit 1
        end
        rm -f -- "$download"
        beeper_promote "$app_dir" "$state_dir" "$staged" "$url"; or exit 1
        echo "Installed $url"
    case validate-paths
        beeper_validate_paths; or exit 1
    case resolve-build
        set -l arch (beeper_architecture); or exit 1
        set -l endpoint "https://api.beeper.com/desktop/download/linux/$arch/stable/com.automattic.beeper.desktop"
        set -l url (curl --fail --silent --show-error --head --location --retry 2 --connect-timeout 15 --max-time 60 --proto '=https' --proto-redir '=https' --output /dev/null --write-out '%{url_effective}' "$endpoint"); or exit 1
        if not string match -rq '^https://([a-zA-Z0-9-]+\\.)*beeper\\.com/[^[:space:]]+$' -- "$url"
            echo 'Resolved URL is not on official Beeper HTTPS infrastructure' >&2
            exit 1
        end
        echo "$url"
    case run run-extract run-wayland
        set -l app "$HOME/.local/opt/beeper/Beeper.AppImage"
        if not test -x "$app"; or not test -f "$app"
            echo 'Beeper AppImage is not executable or not installed' >&2
            exit 1
        end
        if test "$argv[1]" = run-extract
            set -gx APPIMAGE_EXTRACT_AND_RUN 1
        else if test "$argv[1]" = run-wayland
            set -gx electron_ozone_platform_hint auto
        end
        exec "$app" $argv[2..-1]
    case validate-candidate
        set -l candidate "$argv[2]"
        if test -z "$candidate"; or not test -f "$candidate"; or test -L "$candidate"; or not test -x "$candidate"
            echo 'Candidate is not an executable regular file' >&2
            exit 1
        end
        set -l size (stat -c %s -- "$candidate")
        if test "$size" -lt 1048576
            echo 'Candidate is too small' >&2
            exit 1
        end
        set -l elf (od -An -tx1 -N4 -- "$candidate" | string replace -ar '\\s' '')
        set -l magic (od -An -tx1 -j8 -N3 -- "$candidate" | string replace -ar '\\s' '')
        # AppImage's type-2 magic is recommended, and current Beeper builds omit it.
        if test "$elf" != 7f454c46; or begin; test "$magic" != 414902; and test "$magic" != 000000; end
            echo 'Candidate is not a Type-2 AppImage' >&2
            exit 1
        end
        set -l offset (timeout 10s "$candidate" --appimage-offset 2>/dev/null); or begin
            echo 'AppImage runtime offset check failed' >&2
            exit 1
        end
        if not string match -rq '^[1-9][0-9]{0,12}$' -- "$offset"; or test "$offset" -ge "$size"
            echo 'Invalid AppImage runtime offset' >&2
            exit 1
        end
        set -l squashfs (od -An -tx1 -j "$offset" -N4 -- "$candidate" | string replace -ar '\\s' '')
        if test "$squashfs" != 68737173
            echo 'Missing SquashFS payload' >&2
            exit 1
        end
    case architecture
        beeper_architecture; or exit 1
    case status
        set -l data_home "$XDG_DATA_HOME"
        if test -z "$data_home"
            set data_home "$HOME/.local/share"
        end
        set -l config_home "$XDG_CONFIG_HOME"
        if test -z "$config_home"
            set config_home "$HOME/.config"
        end
        set -l state_home "$XDG_STATE_HOME"
        if test -z "$state_home"
            set state_home "$HOME/.local/state"
        end
        set -l app "$HOME/.local/opt/beeper/Beeper.AppImage"
        if test -f "$app"
            echo 'Beeper: installed'
        else
            echo 'Beeper: not installed'
        end
        echo "AppImage: $app"
        if test -x "$app"
            echo 'Executable: yes'
        else
            echo 'Executable: no'
        end
        if test -f "$state_home/beeper-provision/current-url"
            echo "Build: "(string collect < "$state_home/beeper-provision/current-url")
        else
            echo 'Build: unknown'
        end
        if test -f "$app.prev"
            echo 'Rollback: available'
        else
            echo 'Rollback: unavailable'
        end
        if test -f "$data_home/applications/beeper.desktop"
            echo 'Desktop entry: present'
        else
            echo 'Desktop entry: absent'
        end
        if test -L "$config_home/systemd/user/timers.target.wants/beeper-update.timer"
            echo 'Automatic updates: enabled (configured)'
        else
            echo 'Automatic updates: disabled or unknown'
        end
        if test -f "$state_home/beeper-provision/last-update"
            echo "Last update: "(string collect < "$state_home/beeper-provision/last-update")
        else
            echo 'Last update: unknown'
        end
    case '*'
        echo 'Usage: beeperctl.fish status|purge' >&2
        exit 2
end
