# Dotfiles

Managed with [chezmoi](https://www.chezmoi.io/).

## Workflow

```sh
chezmoi edit ~/.config/fish/config.fish
chezmoi diff
chezmoi apply
```

Niri configuration is managed only on Linux. The ThinkPad display settings
are scoped to `thinkpad`; Thor uses its own existing desktop configuration.
The keyd configuration is validated and installed into `/etc/keyd/default.conf` with `sudo` only when its content changes.

Packages required by the managed configuration are declared in
`.chezmoidata/packages.yaml` and installed by chezmoi when that list changes.
The list intentionally excludes operating-system defaults, hardware drivers,
and unrelated applications. Entries under `manual` are installed and updated
by their vendor or from source rather than the system package manager; Codex
uses OpenAI's standalone installer.

The `ddcutil` package supplies the udev permissions and kernel module
configuration needed for external-monitor brightness control. On the ThinkPad,
the brightness keys use DDC/CI for the ASUS XG32UCWMG and fall back to Noctalia
for the laptop panel.

`bolt` provides Thunderbolt dock authorization. The Kensington SD2480T UUID is
stored in `.chezmoidata/devices.yaml`; chezmoi enrolls it when visible and not
already stored. Connect the dock and run `chezmoi apply` on a new ThinkPad.

The Tailscale service is enabled and started automatically. Authentication is
deliberately manual; on a new machine, run `sudo tailscale up --ssh` after
applying the dotfiles.

Fish's generated `fish_variables` file is intentionally not managed. Put
portable Fish configuration in `config.fish`, `conf.d`, or `functions` instead.

## Thor (Ubuntu ARM64)

`thor` is an Acer Veriton GN100 running Ubuntu 24.04 on ARM64. Its hostname
selects overrides in `.chezmoitemplates/thor` for the existing Bash environment,
Niri desktop/keybindings, and Event Horizon Ghostty theme. The experimental
Niri HDR configuration is tracked separately and includes the same base desktop.
Thor does not receive the ThinkPad's modular Niri config or monitor-brightness
helper, which expects Noctalia rather than Thor's Omarchy Quickshell.

The Ubuntu `apt` list uses Ubuntu package names for system/service prerequisites. Developer CLIs use the Thor-only mise config.
Packages are installed only when missing. ARM64 vendor binaries and source
builds are listed under `manual`; chezmoi does not build or replace those.
The Niri/HDR binaries, Omarchy Quickshell, Event Horizon services/assets and
local launcher scripts remain prerequisites from the existing machine setup.
This repo captures its dotfiles, not a full bare-metal bootstrap.

The active checkout on Thor is `~/dev/dotfiles`. To use that location on a
fresh machine after cloning:

```sh
mkdir -p ~/.config/chezmoi
printf 'sourceDir = "%s/dev/dotfiles"\numask = 0o077\n' "$HOME" > ~/.config/chezmoi/chezmoi.toml
chezmoi diff
chezmoi apply
```

Ubuntu's Bash login profile loads `~/.profile`, preserving its user PATH setup.
Thor's Bash overrides retain the Cargo, Codex, Grok and OpenCode environment.
Keyd and Tailscale reuse the shared Linux setup; changing system configuration
or installing missing packages requires `sudo`.

## Planned platform structure

```text
shared configuration
├── fish
├── git
└── editors

Linux only
├── niri
└── keyd

macOS only
├── Brewfile
└── optional Karabiner configuration
```

## Thor pinned developer tools

Mise 2026.10.4 owns the exact versions in `dot_config/mise/config.toml.tmpl`.
Bash and Zsh activate it; `mup --dry-run` previews upgrades, and `mup` asks before
upgrading and re-pinning, then prints the config diff. Review major-version
compatibility and copy the reviewed config into this template before committing.
`mup` requires Python 3 (provided by Ubuntu) for its scope check. It refuses
to run when mise loads additional configs or tool-version environment overrides;
resolve those overrides before retrying. It never upgrades a caller’s project.
Previous tool versions are retained for rollback. If an upgrade fails, `mup`
prints the partial diff and retains the original config at the reported backup
path; review it before restoring the config and retrying.
No upgrade scheduler is installed. Install mise with its official installer and
`MISE_VERSION=v2026.10.4`, then restore this config and run `mise install`.

Rollback: `mise use -g micro@2.0.14 && mise install`; verify `micro --version`.
This was tested, then restored to 2.0.15. For a committed upgrade, `git revert`
the upgrade commit, review/apply the config with chezmoi, and `mise install`.
Keep previous binaries until verification succeeds. The local before inventory
and shell backups are in `~/.local/state/thor-packages/2026-11-08/`.

The migration is incomplete: Snaps and custom
desktop builds remain in place, as do existing Ansible, Rust and AI app installs.
See homelab `fleet/docs/thor-packages.md` for the precise remaining work.

## Thor desktop app sources

For developer tools, runtimes and CLIs, use mise first. For desktop apps, prefer:

1. An official vendor AppImage with verified Linux ARM64 support and working in-app updates.
2. An official vendor apt repository or .deb.
3. Flatpak.

If the AppImage lacks a working updater, use the next supported source. Keep
one active install source per app; verify the new version launches and preserves
its profile before retiring the old install.

Andy may explicitly initiate in-app updates. Do not enable unattended updates
or scheduled updaters. Record each accepted version, vendor release URL, ARM64
architecture and SHA256 in the app's checked-in declaration. Verify vendor
signatures/checksums where available. Use a versioned vendor download when an
updater cannot supply a reproducible release artifact. Keep the previous image
outside the active launcher path and back up app data before an update. Rollback
restores the previous image/launcher and matching data backup if needed, then
reverts the version declaration in Git. `mup` handles mise tools only.

This source preference does not replace working desktop apps automatically.
Ubuntu core, kernel, NVIDIA, CUDA and essential services retain their supported
Ubuntu/NVIDIA sources.

### Thor OLED window edges

Niri uses thin, dim teal edges. `niri-border-animation.service` rotates the
focus-ring and border gradient by 3 degrees each second (one turn in two
minutes), using Niri's live config reload. It updates only the generated
`~/.config/niri/animated-border.kdl`; chezmoi creates that file once and leaves
its runtime contents alone. The helper starts with the graphical session.

To pause the rotation at its current angle, run
`systemctl --user stop niri-border-animation.service`; use `start` to resume.
The rotation changes color distribution, not the position of the edge.

The Thor Quickshell top bar auto-hides on every output. Move the pointer to
the topmost screen edge to reveal it; leaving the bar hides it after 400 ms.
Tray menus keep the bar open until dismissed. The hidden trigger is transparent
and one logical pixel tall, and the bar overlays windows without reserving
space or resizing them. Its configuration and required artwork are managed
under `dot_config/quickshell/omarchy-niri`. Restart with
`systemctl --user restart omarchy-niri-shell.service` if needed.

Thor starts the Event Horizon screensaver after two idle minutes and powers
off the displays via Niri DPMS after four idle minutes total. Input wakes the
displays and stops the saver. This does not lock or suspend the computer.
The timer is managed in `dot_config/systemd/user/event-horizon-idle.service`.
