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

## Platform layout

Keep the source tree shaped like the target home directory. Platform-specific
files stay in their normal target location and are selected with
`.chezmoiignore` or templates; do not create top-level `linux/` and `macos/`
directories, because chezmoi would treat them as files to deploy into `$HOME`.

```text
~/.local/share/chezmoi/
├── .chezmoiignore
├── .chezmoitemplates/
│   └── keyd-default.conf                 # Linux
├── dot_config/
│   ├── fish/                             # Shared; template OS differences
│   ├── ghostty/                          # Shared
│   ├── micro/                            # Shared
│   ├── zed/                              # Shared
│   ├── niri/                             # Linux only
│   └── karabiner/                        # macOS only, if needed
├── dot_bashrc.tmpl                       # Shared with OS conditions
├── dot_Brewfile                          # macOS only, planned
├── dot_gitconfig.tmpl                    # Shared
├── dot_zshrc.tmpl                        # Shared with OS conditions
├── run_onchange_after_install-keyd.sh.tmpl
└── run_onchange_before_install-packages-darwin.sh.tmpl  # Planned
```

The platform rules belong in `.chezmoiignore`:

```text
{{- if ne .chezmoi.os "linux" }}
.config/niri
{{- end }}
{{- if ne .chezmoi.os "darwin" }}
.Brewfile
.config/karabiner
{{- end }}
```

Only add the macOS entries when their corresponding files exist. Scripts that
modify `/etc` or install packages must also guard themselves with
`.chezmoi.os`, even when their target files are ignored.

## Adding the first Mac

Install and authenticate the bootstrap tools first:

```sh
brew install chezmoi gh
gh auth login
gh auth setup-git
```

Initialize without immediately changing the home directory, inspect the
rendered result, and then apply it:

```sh
chezmoi init andrewjohnharvey
chezmoi diff
chezmoi apply
```

After confirming the shared configuration works, capture Mac-specific files on
the Mac itself. For example:

```sh
chezmoi add ~/.config/karabiner
chezmoi add ~/.Brewfile
chezmoi diff
```

Before committing, add matching `darwin` conditions to `.chezmoiignore` and
template only the files whose contents genuinely differ by OS, architecture,
or hostname. Finish with:

```sh
chezmoi apply
chezmoi cd
git status
git add .
git commit -m "Add macOS configuration"
git push
```
