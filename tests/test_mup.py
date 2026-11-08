"""Exercise mup without installing tools or touching the operator's home."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
MUP = ROOT / "private_dot_local/bin/executable_mup"


class MupTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.config_dir = self.home / ".config/mise"
        self.config_dir.mkdir(parents=True)
        self.config = self.config_dir / "config.toml"
        self.original = '[tools]\nmicro = "2.0.14"\n'
        self.config.write_text(self.original)
        self.log = self.home / "calls"
        mise = self.home / ".local/bin/mise"
        mise.parent.mkdir(parents=True)
        mise.write_text("""#!/usr/bin/env bash
set -eu
if [[ $1 == config ]]; then
    printf '[{"path":"%s/.config/mise/config.toml"}%s]\\n' "$HOME" "${EXTRA_CONFIG:-}"
    exit 0
fi
printf '%s|%s\\n' "$PWD" "$*" >> "$HOME/calls"
if [[ " $* " == *' --dry-run '* ]]; then
    exit "${PREVIEW_STATUS:-0}"
fi
printf '[tools]\\nmicro = "2.0.15"\\n' > config.toml
exit "${UPGRADE_STATUS:-0}"
""")
        mise.chmod(0o755)
        self.project = self.home / "project"
        self.project.mkdir()
        self.project_config = self.project / "mise.toml"
        self.project_config.write_text('[tools]\nnode = "22.0.0"\n')
        self.env = {**os.environ, "HOME": str(self.home)}

    def run_mup(self, *args: str, answer: str = "", **env: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", str(MUP), *args], input=answer, text=True,
            capture_output=True, cwd=self.project, env={**self.env, **env}, check=False,
        )

    def calls(self) -> list[str]:
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_preview_never_installs(self) -> None:
        result = self.run_mup("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [f"{self.config_dir}|upgrade --bump --no-prune --dry-run"])
        self.assertEqual(self.config.read_text(), self.original)

    def test_decline_never_installs(self) -> None:
        result = self.run_mup(answer="n\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual(self.config.read_text(), self.original)

    def test_upgrade_keeps_old_tools_and_shows_diff(self) -> None:
        result = self.run_mup(answer="y\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[-1], f"{self.config_dir}|upgrade --bump --no-prune")
        self.assertIn('-micro = "2.0.14"', result.stdout)
        self.assertIn('+micro = "2.0.15"', result.stdout)
        self.assertEqual(list(self.config_dir.glob("config.toml.mup.*")), [])
        self.assertEqual(self.project_config.read_text(), '[tools]\nnode = "22.0.0"\n')

    def test_partial_failure_keeps_original_and_status(self) -> None:
        result = self.run_mup(answer="Y\n", UPGRADE_STATUS="42")
        self.assertEqual(result.returncode, 42, result.stderr)
        backups = list(self.config_dir.glob("config.toml.mup.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), self.original)
        self.assertIn(str(backups[0]), result.stderr)
        self.assertIn('+micro = "2.0.15"', result.stdout)

    def test_preview_failure_stops_before_confirmation(self) -> None:
        result = self.run_mup(answer="y\n", PREVIEW_STATUS="17")
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual(self.config.read_text(), self.original)

    @unittest.skipUnless(os.environ.get("MISE_BINARY"), "set MISE_BINARY for real discovery check")
    def test_real_mise_ancestor_config_blocks_upgrade(self) -> None:
        mise = self.home / ".local/bin/mise"
        mise.unlink()
        mise.symlink_to(os.environ["MISE_BINARY"])
        (self.home / "mise.toml").write_text('[tools]\nnode = "22.0.0"\n')
        result = self.run_mup(
            "--dry-run", MISE_DATA_DIR=str(self.home / "data"),
            MISE_STATE_DIR=str(self.home / "state"), MISE_CACHE_DIR=str(self.home / "cache"),
            MISE_TRUSTED_CONFIG_PATHS=str(self.home),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected mise configs", result.stderr)
        self.assertEqual(self.config.read_text(), self.original)
        self.assertEqual(self.calls(), [])

    def test_extra_config_blocks_upgrade(self) -> None:
        result = self.run_mup(answer="y\n", EXTRA_CONFIG=',{"path":"/other/mise.toml"}')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unexpected mise configs", result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertEqual(self.config.read_text(), self.original)

    def test_environment_version_override_blocks_upgrade(self) -> None:
        result = self.run_mup(answer="y\n", MISE_MICRO_VERSION="latest")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("MISE_MICRO_VERSION", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_invalid_arguments_never_call_mise(self) -> None:
        for args in [("--bad",), ("--dry-run", "extra")]:
            with self.subTest(args=args):
                result = self.run_mup(*args)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
