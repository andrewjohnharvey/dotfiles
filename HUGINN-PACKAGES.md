# Huginn packages

Applied on huginn, x86_64 CachyOS, on 2026-11-08. Merge performs no deployment.
Only huginn's template branches change. No homelab files or other machines changed.

Pacman retains the OS, system dependencies and general packages. Mise 2026.10.4
owns the nine exact runtime and coding-agent versions in the huginn config.
Rust was absent; no Rust toolchain was added. Chezomoi 2.74.0 was installed through
mise only as an unactivated verification utility, not as a managed general package.

Existing runtimes and agents were migrated at their installed versions. Each
replacement passed a version invocation before PATH changed. Fish is the login
shell; Fish and Bash login resolution passed. T3's existing active-runtime
function is preserved and its version invocation passed. These checks do not
exercise authenticated prompts or reopen the running T3 GUI.

`mup --dry-run` previews changes. `mup` asks before upgrading, retains the previous
config, upgrades with exact pins, and prints the diff. Copy reviewed pins back
into `dot_config/mise/config.toml.tmpl` before committing. No timer or automatic
upgrade was added. Automatic upgrade pruning is disabled to retain rollback tools.
The command is `~/.local/bin/huginn-mup`, with a `mup` symlink and shell functions.

`mup --rollback` restores the previous config from
`~/.local/state/huginn-packages/upgrades/latest.toml` and runs `mise install`.
A real downgrade to Bun 1.3.10 followed by restoration to 1.3.11 passed. For a
committed change, revert the pin commit, apply only the reviewed huginn targets,
and run `mise install`. Do not apply the whole dotfiles repository blindly.

Inventory, shell backups, archived duplicate entry points and verification are in
`~/.local/state/huginn-packages/2026-11-08/`. Existing Codex and Claude payloads
remain for running sessions; their old user-bin symlinks were archived. Hermes'
isolated environment and Node payload remain intact. Bun's globally installed
OpenClaw and codex-monorepo source/build tree remain intact. Ansible and nano-pdf
remain uv tools. Other standalone general tools remain unchanged.

No sudo action is recommended. `pacman -R --print nodejs npm` failed dependency
validation because node-gyp, nodejs-nopt and semver require nodejs. Keep pacman's
Node and Python for system dependencies; mise supplies the developer versions.
Foreign packages reported by `pacman -Qm`: 1password 8.12.42-36,
1password-cli 2.40.0-1, jack 0.126.0-6. Leave all three unchanged.
No Flatpak, pipx, cargo, rustup, asdf, nvm or pyenv executable was found.

No desktop app was migrated. Existing Grok-Bot.AppImage and downloaded
Obsidian-1.12.7.AppImage have hashes in additional-inventory.txt; vendor URLs and
working in-app updates were not established. Do not treat the filenames as
verified release versions. Obsidian's pacman installation remains active. Prefer
an official vendor AppImage only after verifying its in-app updater; otherwise
keep pacman or use Flatpak. Record version, URL and SHA256 and retain the prior
image before any future migration. Updates require Andy to start them.

This PR branches from origin/main. It uses Thor PR #4's mise config path and host
conditional structure, but does not include Thor's unmerged changes. Its command
implementation has a huginn-specific name. When combining the PRs, retain both
host branches in the config and allow each host in .chezmoiignore. Resolve the
shared file additions by retaining both hosts, never replacing Thor's pins.
