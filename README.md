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

Packages required by the managed configuration are declared in
`.chezmoidata/packages.yaml` and installed by chezmoi when that list changes.
The list intentionally excludes operating-system defaults, hardware drivers,
and unrelated applications. Entries under `manual` are installed and updated
by their vendor rather than Pacman; Codex uses OpenAI's standalone installer.

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

## Herdr

Herdr preferences and plugin shortcuts are managed in
`dot_config/herdr/config.toml.tmpl`. macOS uses Command for new-tab and
Reviewr shortcuts; Linux uses Ctrl. Other settings are shared.

Install Herdr separately and install these plugins through Herdr before using
their shortcuts:

- `persiyanov/herdr-reviewr`: v0.21.0, commit
  `bbeaac7b10fadd97278232b478470234d6078112`.
- `jhochenbaum/herdr-hunk-diff`: v0.2.0, commit
  `ad6f670b78887cd0becb473fd486945e5255c062`.

Only `~/.config/herdr/config.toml` is managed. Plugin registries and binaries,
sessions, sockets, and logs stay local to each machine. If a plugin changes
its shortcuts in the live config, bring those edits back into the template
before applying chezmoi again.

Preview and apply just the Herdr configuration:

```sh
chezmoi diff ~/.config/herdr/config.toml
chezmoi apply ~/.config/herdr/config.toml
```

Use Herdr's reload-config menu after applying to a running session.
