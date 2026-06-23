# Dotfiles

Managed with [chezmoi](https://www.chezmoi.io/).

## Workflow

```sh
chezmoi edit ~/.config/fish/config.fish
chezmoi diff
chezmoi apply
```

Niri is installed only on Linux. Its display configuration is currently scoped
to the `thinkpad` hostname. The keyd configuration is validated and installed
into `/etc/keyd/default.conf` with `sudo` only when its content changes.

Required Arch-family packages are declared in `.chezmoidata/packages.yaml` and
installed by chezmoi when that list changes. The `ddcutil` package supplies the
udev permissions and kernel module configuration needed for external-monitor
brightness control. On the ThinkPad, the brightness keys use DDC/CI for the
ASUS XG32UCWMG and fall back to Noctalia for the laptop panel.

Fish's generated `fish_variables` file is intentionally not managed. Put
portable Fish configuration in `config.fish`, `conf.d`, or `functions` instead.

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
