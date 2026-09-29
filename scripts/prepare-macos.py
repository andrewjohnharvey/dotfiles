#!/usr/bin/env python3
"""Back up managed Mac settings and preserve private overrides before first apply."""
import datetime
import json
import os
from pathlib import Path
import platform
import re
import shutil

if platform.system() != 'Darwin':
    raise SystemExit('This preparation step is only for macOS.')
os.umask(0o077)
home = Path.home()
private = home / '.config/chezmoi'
marker = private / 'macos-prepared-v1'
if marker.exists():
    print('macOS private settings already prepared; no files changed.')
    raise SystemExit(0)

# Parse JSONC without printing settings or credential values.
def jsonc(text):
    token = r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*.*?\*/|,(?=\s*[}\]])'
    text = re.sub(token, lambda m: m[0] if m[0].startswith('"') else '', text, flags=re.S)
    return json.loads(text)

zed = home / '.config/zed/settings.json'
context = jsonc(zed.read_text()).get('context_servers', {}) if zed.exists() else {}
copies = {
    '.zshrc': '.zshrc.local',
    '.zprofile': '.zprofile.local',
    '.bashrc': '.bashrc.local',
    '.bash_profile': '.bash_profile.local',
    '.gitconfig': '.gitconfig.local',
    '.config/fish/config.fish': '.config/fish/config.local.fish',
}
# Fail closed if a user already has different local overrides.
for source, target in copies.items():
    src, dst = home / source, home / target
    if dst.exists() and (not src.exists() or src.read_bytes() != dst.read_bytes()):
        raise SystemExit('Reconcile existing private override before proceeding: ' + str(dst))
context_path = private / 'zed-context-servers.json'
if context_path.exists() and json.loads(context_path.read_text()) != context:
    raise SystemExit('Reconcile existing private Zed context settings before proceeding.')

stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
backup = home / '.local/state/chezmoi-backups' / (stamp + '-macos')
backup.mkdir(parents=True, mode=0o700)
paths = list(copies) + [
    '.Brewfile', '.aerospace.toml', '.hammerspoon/init.lua',
    '.config/alacritty/alacritty.toml', '.config/ghostty/config',
    '.config/ghostty/config.ghostty', '.config/ghostty/themes/Houston',
    '.config/herdr/config.toml', '.config/herdr/plugins.json',
    '.config/karabiner/karabiner.json', '.config/rift/config.toml',
    '.config/zed/settings.json', '.config/zed/keymap.json', '.config/zed/tasks.json',
    '.config/zed/themes/houston_zed_theme.json', '.config/micro/settings.json',
    '.config/micro/colorschemes/catppuccin-macchiato.micro',
    '.config/fish/functions/ccd.fish', '.config/fish/functions/fish_user_key_bindings.fish',
    'Library/Application Support/Code/User/settings.json',
    'Library/Application Support/Cursor/User/settings.json',
    'Library/Application Support/Cursor/User/keybindings.json',
]
for name in paths:
    src, dst = home / name, backup / name
    if src.is_file():
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        dst.chmod(0o600)
for source, target in copies.items():
    src, dst = home / source, home / target
    if src.is_file() and not dst.exists():
        shutil.copy2(src, dst)
        dst.chmod(0o600)
private.mkdir(parents=True, exist_ok=True, mode=0o700)
if not context_path.exists():
    context_path.write_text(json.dumps(context, indent=2) + '\n')
    context_path.chmod(0o600)
marker.write_text(str(backup) + '\n')
print('Private backup and local overrides prepared. Backup: ' + str(backup))
