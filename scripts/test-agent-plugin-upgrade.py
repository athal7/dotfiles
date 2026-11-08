#!/usr/bin/env python3
"""Exercise managed plugin updates without touching the user's installations."""
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
            path.write_text(f'#!/bin/sh\nprintf "%s\\n" "{name} $*" >> "$LOG"\n'
                            '[ "$*" != "plugin outdated" ] || echo "${AOE_OUTDATED:-needs update  example.plugin old -> new}"\n')
            path.chmod(0o755)
        self.config = self.home / ".config/agent-of-empires/config.toml"
        self.config.parent.mkdir(parents=True)
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

    def run_upgrade(self, source):
        self.config.write_text(f'[plugins."example.plugin"]\nsource = "{source}"\n')
        return subprocess.run(["bash", str(self.script)], env=self.env, cwd=self.home,
                              capture_output=True, text=True)

    def test_updates_only_declared_and_trusted_sources(self):
        result = self.run_upgrade("gh:example/plugin@main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            "brew update", "brew upgrade --no-ask", "mise upgrade --yes -x node",
            "omp plugin upgrade @example/plugin", "aoe plugin outdated",
            "aoe plugin update example.plugin --yes"])

    def test_current_plugin_is_not_rebuilt(self):
        self.env["AOE_OUTDATED"] = "up to date    example.plugin abcdef12"
        result = self.run_upgrade("gh:example/plugin@main")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("aoe plugin update ", self.log.read_text())

    def test_rejects_untrusted_source_and_reports_failure(self):
        result = self.run_upgrade("gh:other/plugin@main")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("source differs", result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [
            "brew update", "brew upgrade --no-ask", "mise upgrade --yes -x node",
            "omp plugin upgrade @example/plugin", "aoe plugin outdated"])


if __name__ == "__main__":
    unittest.main()
