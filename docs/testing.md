# Testing

`mise run test` runs deterministic tests with temporary HOME and XDG directories and fake network and systemd commands. Individual groups are `mise run test:unit`, `mise run test:integration`, and `mise run test:safety`. They do not require network access. The tests include failure injection, transaction recovery, ownership collisions, path guards, launch quoting, timer lifecycle, and profile preservation.

`mise run test:live` is separate: it contacts both official architecture endpoints, downloads the host architecture's AppImage into a temporary HOME, checks its final URL and runtime structure, and removes the temporary artifact. It does not install Beeper into the real HOME. It executes the downloaded runtime for the offset check and does not launch the GUI.

For profile-path research, Beeper 4.3.264 x86_64 was separately started on 2026-10-31 in a disposable, network-isolated bubblewrap environment with a virtual display and independent HOME and XDG directories. It created `account.db`, `index.db`, and other profile files under `XDG_CONFIG_HOME/BeeperTexts`; no application-specific top-level directory appeared in XDG data, state, or cache during that unsigned-in session. This observation supports the scoped purge target; it does not establish every legacy or signed-in data location.

Check syntax with `fish -n beeperctl.fish` and each Fish file under `tests/`. Test fixtures represent runtime behavior but are not substitutes for a live application or desktop-session smoke test.
