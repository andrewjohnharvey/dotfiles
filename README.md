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

## macOS bootstrap

Install Homebrew and Python 3 first. Initialize without applying, then preserve
existing settings before previewing any changes:

```sh
brew install chezmoi python
chezmoi init --branch codex/inventory-installed-packages https://github.com/andrewjohnharvey/dotfiles.git
python3 "$(chezmoi source-path)/scripts/prepare-macos.py"
# Preview locally: rendered Zed settings can contain local credentials.
chezmoi diff
chezmoi apply
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --file="$HOME/.Brewfile"
# If required packages are missing:
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --no-upgrade --file="$HOME/.Brewfile"
```

Preparation saves a private backup under `~/.local/state/chezmoi-backups`.
It preserves shell setup in `*.local` files, Fish setup in `config.local.fish`,
and Git identity and machine settings in `~/.gitconfig.local`.
Zed context-server settings stay in `~/.config/chezmoi/zed-context-servers.json`.
The Zed template merges that local file into the rendered settings.
These files are not tracked. Do not add rendered Zed settings or local overrides
back to Git. Edit the portable templates instead. Back up private overrides separately.

The preparation marker makes reruns harmless. A pre-apply guard refuses an
unprepared Mac. Existing conflicting local overrides require manual reconciliation.
On a fresh Mac, set Git identity in `~/.gitconfig.local` and install optional
shell customizations separately. The preserved Powerbook shell uses Oh My Zsh,
Powerlevel10k, and local work tooling; these are not copied to other machines.

The Brewfile lists config dependencies only. Packages and GUI apps are not
installed or upgraded automatically by `chezmoi apply` on macOS. Homebrew tap
trust decisions remain local. Linux package, keyd, dock, and Tailscale scripts
render empty on macOS; Niri and monitor-brightness are excluded.

### Captured app configuration

Versions below were inspected on Powerbook on 2026-09-29. They document the
capture, not version locks. macOS additions are ignored on Linux.

| App | Version | Managed preferences |
| --- | --- | --- |
| Ghostty | 1.3.1 | Existing config, Houston theme, native Command/Herdr shortcuts |
| Alacritty | 0.17.0 | Existing Shift+Enter binding; native defaults retained |
| Zed | 1.20.2 | Portable settings, keymap, tasks, Houston theme; credentials local |
| VS Code | 1.118.1 | Existing user settings |
| Cursor | 2.6.22 | Existing user settings and keybindings |
| Karabiner-Elements | 16.3.0 | Existing keyboard profile and modifier mappings |
| AeroSpace | 0.20.3-Beta | Existing layout, keybindings, and app rules |
| Rift | 0.5.10 | Existing scrolling layout, workspaces, app rules, and shortcuts |
| Hammerspoon | 1.1.1 | Existing iPhone Mirroring window behavior |
| Herdr | 0.8.0 | Shared preferences with native Mac shortcuts; see below |
| Micro | 2.0.15 | Shared settings and the selected Catppuccin theme file |

The Mac keeps its existing Ghostty `config` file. Linux keeps `config.ghostty`
with keyd clipboard mappings. The comment-only Ghostty file under Library stays
unmanaged. Existing Git identity, shell customization, and Zed credentials are
preserved. AeroSpace, Rift, and Hammerspoon are not launched or enabled by apply.

### Exclusions

Only reviewed text preferences are captured. Library preferences are not dumped.
Credentials, keys, auth stores, histories, sessions, caches, databases, and binary
state stay local, including Herdr's plugin registry and running sessions.
OmniWM 0.6.8 settings mix monitor IDs and UI state; its legacy JSON and current
TOML remain local. VS Code Insiders 1.137.0-insider settings include machine-specific
agent command approvals and remain local. Kitty and WezTerm had no custom config
to capture. Raycast, browsers, Office, chat apps, and other installed GUI apps
keep their account/runtime stores. Fish is optional and was not installed on
Powerbook; its existing PAI function is preserved locally.

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

Install the pinned plugins using Herdr's supported CLI (Node is required for Hunk Diff):

```sh
herdr plugin install persiyanov/herdr-reviewr --ref bbeaac7b10fadd97278232b478470234d6078112 --yes
herdr plugin install jhochenbaum/herdr-hunk-diff --ref ad6f670b78887cd0becb473fd486945e5255c062 --yes
herdr plugin list
```

These commands follow the [Herdr plugin installation workflow](https://herdr.dev/docs/marketplace/).
Use `herdr server reload-config` for the intended running session, or the reload
menu. Do not stop a server to refresh config.
