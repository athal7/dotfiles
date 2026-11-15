#!/usr/bin/env python3
"""Exercise the upgrade script without touching the user's installations."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PluginUpgradeTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.log = self.home / "calls"
        for name in ("brew", "mise", "omp", "aoe"):
            path = self.bin / name
            path.write_text(f'#!/bin/sh\nprintf "%s\\n" "{name} $*" >> "$LOG"\n')
            path.chmod(0o755)
        self.overlay = self.home / "data.json"
        self.overlay.write_text(json.dumps({"packages": {
            "omp_plugins": ["@example/plugin"],
            "aoe_plugins": [{"id": "example.plugin", "source": "gh:example/plugin@main"}],
        }}))
        self.env = dict(os.environ, HOME=str(self.home), LOG=str(self.log),
                        PATH=f"{self.bin}:{os.environ['PATH']}")
        script = subprocess.run(["chezmoi", "execute-template", "-S", str(ROOT),
                                 "--override-data-file", str(self.overlay), "--file",
                                 str(ROOT / "dot_local/bin/executable_agent-plugin-upgrade.tmpl")],
                                env=self.env, capture_output=True, text=True, check=True)
        self.script = self.home / "upgrade.sh"
        self.script.write_text(script.stdout)

    def test_upgrades_package_managers_and_omp_while_leaving_aoe_plugins_to_aoe(self):
        result = subprocess.run(["bash", str(self.script)], env=self.env, cwd=self.home,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            "brew update", "brew upgrade --no-ask", "mise upgrade --yes -x node",
            "omp plugin upgrade @example/plugin"])

    def test_reports_a_failed_homebrew_update(self):
        brew = self.bin / "brew"
        brew.write_text('#!/bin/sh\nexit 1\n')
        brew.chmod(0o755)
        result = subprocess.run(["bash", str(self.script)], env=self.env, cwd=self.home,
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Homebrew update failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
