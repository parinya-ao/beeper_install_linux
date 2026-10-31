# Beeper user-local provisioning

Install or repair Beeper and enable the daily user timer:

```fish
mise run provision
```

To leave automatic updates disabled, run `mise run provision:no-autoupdate`. Fish, mise, curl, standard Linux utilities, and a working systemd user manager are expected; this project does not install packages or use root privileges. Beeper requires glibc 2.32 or newer. The AppImage is installed at `~/.local/opt/beeper/Beeper.AppImage`, and the controller at `~/.local/bin/beeperctl`. Desktop, state, cache, and systemd files follow the XDG variables.

## Daily use

```fish
beeperctl status                 # offline, read-only
beeperctl verify                 # check installed invariants
beeperctl doctor                 # includes a network check
beeperctl update                 # resolve and install a new stable build
beeperctl rollback               # swap with the one previous build
beeperctl run                    # normal launch
beeperctl run-extract            # AppImage extraction fallback
beeperctl run-wayland            # opt-in Beeper Wayland workaround
beeperctl smoke                  # explicit process-survival check
beeperctl autoupdate status
beeperctl autoupdate enable
beeperctl autoupdate disable
journalctl --user -u beeper-update.service
```

Equivalent `mise run beeper:<command>` tasks are available for the common operations. `mise run deprovision` or `beeperctl uninstall` removes manager-owned files and preserves Beeper profile data. After closing Beeper, `beeperctl purge --user-data` separately deletes the observed current profile at `$XDG_CONFIG_HOME/BeeperTexts` (default `~/.config/BeeperTexts`). This is destructive. It does not delete older or otherwise unverified profile locations.

The extraction fallback does not install FUSE. Use the Wayland workaround only if the normal launch encounters the [upstream-documented display error](https://help.beeper.com/en_US/troubleshooting/appimage-crash-on-wayland-missing-x-server-or-display). Smoke launches a process and checks it survives briefly; it does not establish that login, messaging, or the GUI works.

## Security and recovery

Downloads use verified HTTPS and official Beeper hosts. No independent upstream signature is verified. Candidate checks execute the downloaded AppImage runtime with `--appimage-offset` and inspect its ELF and SquashFS structure; this is not a GUI health check. A kernel-backed user lock serializes mutations. A transaction marker and one previous binary support interruption recovery; retry `beeperctl update` or `beeperctl rollback` if `verify` reports a pending transaction. Unrelated launcher, controller, and unit files are not overwritten.

See [DESIGN.md](DESIGN.md), [testing](docs/testing.md), and [troubleshooting](docs/troubleshooting.md).
