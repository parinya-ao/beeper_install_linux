# Beeper Linux lifecycle design

This project is intended to manage Beeper as a user-local AppImage without installing system packages or changing shell configuration. The installed Fish, mise, curl, and system utilities are the baseline.

## Safety and recovery

Installation, update, rollback, desktop integration, and removal must validate paths and ownership before mutation, serialize through a bounded lock, and preserve the last working current executable if anything fails. Candidates are staged on the application filesystem and checked before atomic promotion. One previous generation and transaction metadata allow interruption recovery. Uninstall preserves user data; explicit purge is confined to the `BeeperTexts` XDG config directory observed in the isolated runtime experiment documented in [testing](docs/testing.md). It does not guess legacy paths. Status is offline by default. Doctor distinguishes failed checks from unavailable or unknown checks.

The desktop launcher and user service files belong to this manager only when ownership is established; unrelated files must never be overwritten. Automatic updates use a daily persistent systemd user timer with a randomized delay; a disabled-timer installation remains possible. Failure to enable or verify the timer must be visible and repairable. Paths must be escaped for their respective desktop and systemd formats, including spaces and special characters.

Official endpoints must use verified HTTPS, and the final resolved URL must be checked against metadata before downloading an unchanged release. An AppImage candidate must be large enough, executable, structurally Type 2, and return a plausible non-GUI runtime offset. This executes upstream runtime code and does not establish GUI health or independent authenticity. Real provisioning is permitted only after the isolated test and live validation gates pass.

Launch normally with minimal flags; provide an explicit extract-and-run fallback, optional Wayland compatibility, and an explicitly invoked smoke test. Beeper requires glibc 2.32 or later. Relevant upstream references: [Beeper downloads](https://www.beeper.com/download), [glibc requirement](https://help.beeper.com/linux-beeper-appimage-not-starting), [Wayland workaround](https://help.beeper.com/en_US/troubleshooting/appimage-crash-on-wayland-missing-x-server-or-display), [AppImage runtime](https://docs.appimage.org/user-guide/run-appimages.html), [FUSE fallback](https://docs.appimage.org/user-guide/troubleshooting/fuse.html), and [systemd timers](https://freedesktop.org/software/systemd/man/latest/systemd.timer.html).

Desktop icons prefer the image bundled in the AppImage, then the PNG favicon linked by Beeper's official download page, and finally the generic network icon. The downloaded fallback must remain at its exact HTTPS URL and pass a bounded PNG signature and size check.

## Verification gate

Use temporary HOME and XDG directories, controlled fixtures and fake commands for offline tests; test interruption, filesystem errors, lock recovery, invalid paths and downloads, and unrelated-file collisions. Run Fish syntax checks and the complete offline suite. Validate official endpoints and AppImage candidates separately in a sandbox. Only then provision the actual user, check the specific timer, ownership and cleanup, and verify status and doctor. Do not commit or push.
