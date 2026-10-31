# Troubleshooting

Run `beeperctl status`, then `beeperctl verify` and `beeperctl doctor`. Status does not use the network; doctor does. `UNKNOWN` means the check could not prove the property and is not a pass.

If an update was interrupted, retry `beeperctl update`. The controller reconciles its transaction marker before continuing. To return to the previous build, run `beeperctl rollback`. If it reports an ownership or unexpected-file conflict, inspect the named path before changing it; the controller will not remove unknown files automatically.

If the timer cannot be enabled, check `systemctl --user status beeper-update.timer` and `journalctl --user -u beeper-update.service`. A degraded user manager can still run a particular timer; verify that timer directly. `beeperctl autoupdate enable` retries unit installation and activation.

If the AppImage cannot mount, try `beeperctl run-extract`; see [AppImage FUSE troubleshooting](https://docs.appimage.org/user-guide/troubleshooting/fuse.html). For a missing X server or DISPLAY on Wayland, try `beeperctl run-wayland`, which applies [Beeper's documented environment setting](https://help.beeper.com/en_US/troubleshooting/appimage-crash-on-wayland-missing-x-server-or-display). Normal launch does not add Electron flags or disable the GPU.

Uninstall preserves account and profile data. `beeperctl purge --user-data` removes only the currently observed `BeeperTexts` profile and refuses if Beeper is running or the target contains symlinks, foreign-owned files, or mount points. It does not remove older or unverified locations. Beeper documents a separate [GPU cache location](https://help.beeper.com/beeper-on-linux-crashing); that does not by itself justify deleting its parent.
