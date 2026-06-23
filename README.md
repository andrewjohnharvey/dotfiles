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
