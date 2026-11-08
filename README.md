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

The Ubuntu `apt` list uses Ubuntu package names (`gh`, not `github-cli`).
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
