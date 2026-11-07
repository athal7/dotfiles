#!/usr/bin/env python3
"""Exercise managed receipt reconciliation against a real isolated AoE installation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / '.chezmoiscripts/run_after_plugins-aoe-grants.sh.tmpl'


class ManagedGrantsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name).resolve()
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / '.config'),
                        AOE_NO_AUTOSTART='1')
        self.env.pop('AOE_DAEMON_URL', None)
        self.env.pop('AGENT_OF_EMPIRES_PROFILE', None)
        self.source = self.home / 'source'
        self.source.mkdir()
        self.manifest('net')
        self.run_cmd('aoe', 'plugin', 'install', str(self.source), '--yes')
        self.config = self.home / '.config/agent-of-empires/config.toml'
        self.overlay = self.home / 'override.json'
        self.overlay.write_text(json.dumps({'packages': {'aoe_plugins': [
            {'id': 'test.managed', 'source': str(self.source)}]}}))
        self.script = self.home / 'reconcile.sh'
        self.script.write_text(self.run_cmd('chezmoi', 'execute-template', '-S', str(ROOT),
                                           '--override-data-file', str(self.overlay),
                                           '--file', str(SCRIPT)).stdout)

    def run_cmd(self, *args, check=True):
        result = subprocess.run(args, env=self.env, cwd=self.home, text=True,
                                capture_output=True)
        if check and result.returncode:
            self.fail(f'{args}: {result.stdout}\n{result.stderr}')
        return result

    def manifest(self, capability):
        (self.source / 'aoe-plugin.toml').write_text(
            'id = "test.managed"\nname = "Managed"\nversion = "1.0.0"\n'
            f'api_version = 2\ncapabilities = ["{capability}"]\n')

    def grant(self):
        return tomllib.loads(self.config.read_text())['plugins']['test.managed']['grant']

    def test_stale_receipt_updates_trusted_source_once(self):
        first = self.grant()
        self.run_cmd('bash', str(self.script))
        self.assertEqual(self.grant(), first)
        installed = self.home / '.config/agent-of-empires/plugins/test.managed/aoe-plugin.toml'
        installed.write_text(installed.read_text() + '\n# changed after approval\n')
        self.manifest('fs.read')
        self.assertIn('needs approval', self.run_cmd('aoe', 'plugin', 'info', 'test.managed').stdout)
        source_dir = self.home / 'chezmoi-source'
        (source_dir / '.chezmoiscripts').mkdir(parents=True)
        script = source_dir / '.chezmoiscripts/run_after_plugins.sh'
        script.write_text(self.script.read_text())
        script.chmod(0o700)
        apply = ('chezmoi', 'apply', '-S', str(source_dir), '-D', str(self.home),
                 '--persistent-state', str(self.home / 'state.boltdb'))
        self.run_cmd(*apply)
        repaired = self.grant()
        self.assertEqual(repaired['capabilities'], ['fs.read'])
        self.assertIn('state:      enabled', self.run_cmd('aoe', 'plugin', 'info', 'test.managed').stdout)
        self.run_cmd(*apply)
        self.assertEqual(self.grant(), repaired)

    def test_missing_managed_plugin_is_installed(self):
        shutil.rmtree(self.home / '.config/agent-of-empires/plugins/test.managed')
        self.run_cmd('bash', str(self.script))
        self.assertIn('state:      enabled', self.run_cmd('aoe', 'plugin', 'info', 'test.managed').stdout)

    def test_source_mismatch_fails_without_mutation(self):
        before = self.config.read_bytes()
        self.overlay.write_text(json.dumps({'packages': {'aoe_plugins': [
            {'id': 'test.managed', 'source': '/not/trusted'}]}}))
        self.script.write_text(self.run_cmd('chezmoi', 'execute-template', '-S', str(ROOT),
                                           '--override-data-file', str(self.overlay),
                                           '--file', str(SCRIPT)).stdout)
        result = self.run_cmd('bash', str(self.script), check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('source differs', result.stderr)
        self.assertEqual(self.config.read_bytes(), before)

    def test_template_preserves_distinct_receipts_and_local_settings(self):
        self.config.write_text('''
[plugins."agent-of-empires.github".grant]
manifest_hash = "sha256:first"
capabilities = ["net"]
granted_at = "2026-01-01T00:00:00Z"
[plugins."agent-of-empires.github".settings]
custom = "retained"
[plugins."community.linear".grant]
manifest_hash = "sha256:second"
capabilities = ["fs.read"]
granted_at = "2026-01-02T00:00:00Z"
[plugins."community.linear".settings]
custom = "retained"
[plugins."local.example".settings]
custom = "untouched"
''')
        before = tomllib.loads(self.config.read_text())['plugins']
        rendered = self.run_cmd('chezmoi', 'cat', '-S', str(ROOT), str(self.config)).stdout
        plugins = tomllib.loads(rendered)['plugins']
        for plugin in ('agent-of-empires.github', 'community.linear'):
            self.assertEqual(plugins[plugin]['grant'], before[plugin]['grant'])
            self.assertEqual(plugins[plugin]['settings']['custom'], 'retained')
        self.assertEqual(plugins['local.example'], before['local.example'])


if __name__ == '__main__':
    unittest.main()
