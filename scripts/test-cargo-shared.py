#!/usr/bin/env python3
"""Exercise cargo-shared against real Cargo, Kache and disposable repositories."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / 'dot_local/bin/executable_cargo-shared.tmpl'


class CargoSharedTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.repo = self.base / 'repo'
        self.repo.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.repo)], check=True)
        self.home = self.base / 'home'
        config = self.home / '.config/kache/aoe.toml'
        config.parent.mkdir(parents=True)
        config.write_text('[cache]\ntarget_liveness = true\nauto_clean_unused_units_days = 0\nauto_clean_orphaned_targets = false\n')
        self.env = {'HOME': str(self.home), 'PATH': os.environ['PATH'], 'TMPDIR': str(self.base),
                    'KACHE_HOST_CONFIG': '', 'KACHE_SEED_NEW_TARGETS': '0', 'KACHE_SEED_INCREMENTAL': '0'}
        rendered = subprocess.run(['chezmoi', 'execute-template', '--override-data',
                                   json.dumps({'rust_cache': {'repository': str(self.repo)}}),
                                   '--file', str(TEMPLATE)], check=True, capture_output=True, text=True)
        self.wrapper = self.base / 'cargo-shared'
        self.wrapper.write_text(rendered.stdout)
        self.wrapper.chmod(0o755)
        self.cache = self.home / 'Library/Caches/kache-aoe-receipts'
        self.kache_env = dict(self.env, RUSTC_WRAPPER='kache',
                              KACHE_CONFIG=str(config), KACHE_CACHE_DIR=str(self.cache),
                              KACHE_SOCKET_PATH=str(self.cache / 'daemon.sock'))
        self.addCleanup(self.stop_daemon)

    def stop_daemon(self):
        subprocess.run(['kache', 'daemon', 'stop'], cwd=self.repo, env=self.kache_env,
                       capture_output=True, timeout=30)

    def call(self, *args, cwd=None, check=True):
        return subprocess.run([str(self.wrapper), *args], cwd=cwd or self.repo, env=self.env,
                              capture_output=True, text=True, check=check, timeout=180)

    def test_guard_and_argument_restrictions(self):
        self.assertNotEqual(self.call('clean', check=False).returncode, 0)
        self.assertNotEqual(self.call('build', '--manifest-path=elsewhere', check=False).returncode, 0)
        self.assertNotEqual(self.call('check', cwd=self.base, check=False).returncode, 0)
        self.assertNotEqual(self.call('build', '--offline', check=False).returncode, 0)


    def test_real_obsolete_pruning_and_active_run_lease(self):
        (self.repo / 'src').mkdir()
        (self.repo / 'dep/src').mkdir(parents=True)
        (self.repo / 'Cargo.toml').write_text('[package]\nname="fixture"\nversion="0.1.0"\nedition="2021"\n[dependencies]\nolddep={path="dep",optional=true}\n[features]\nold=["dep:olddep"]\n')
        (self.repo / 'dep/Cargo.toml').write_text('[package]\nname="olddep"\nversion="0.1.0"\nedition="2021"\n')
        (self.repo / 'dep/src/lib.rs').write_text('pub fn value() -> u32 { 123 }\n')
        (self.repo / 'build.rs').write_text('fn main() { println!("cargo:rerun-if-env-changed=FIXTURE_BLOCK"); if let Ok(p) = std::env::var("FIXTURE_BLOCK") { std::fs::write(format!("{p}.ready"), "").unwrap(); while !std::path::Path::new(&format!("{p}.done")).exists() { std::thread::sleep(std::time::Duration::from_millis(20)); } } }\n')
        source = self.repo / 'src/main.rs'
        source.write_text('fn main() { let a: Vec<_> = std::env::args().collect(); if a.len() > 2 { std::fs::write(&a[1], "ready").unwrap(); while !std::path::Path::new(&a[2]).exists() { std::thread::sleep(std::time::Duration::from_millis(20)); } } }\n')
        self.call('build', '--offline', '--features', 'old')
        deps = self.repo / 'target/debug/deps'
        old = set(deps.glob('libolddep-*'))
        self.assertTrue(old, 'old dependency artifacts were not built')
        source.write_text(source.read_text() + '// refresh source evidence\n')
        ready, done = self.base / 'ready', self.base / 'done'
        proc = subprocess.Popen([str(self.wrapper), 'run', '--offline', '--features', 'old', '--', str(ready), str(done)],
                                cwd=self.repo, env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 120
            while not ready.exists() and proc.poll() is None and time.monotonic() < deadline:
                time.sleep(.05)
            self.assertTrue(ready.exists(), 'cargo run did not reach its live binary')
            blocked = self.call('build', '--offline')
            self.assertIn('busy', blocked.stderr)
            self.assertTrue(all(p.exists() for p in old), blocked.stderr)
        finally:
            done.touch()
            stdout, stderr = proc.communicate(timeout=60)
        self.assertEqual(proc.returncode, 0, stdout + stderr)
        preview = subprocess.run(['kache', '--json', 'clean', '--units', '--dry-run', str(self.repo)],
                                 cwd=self.repo, env=self.kache_env, capture_output=True, text=True, check=True)
        plan = json.loads(preview.stdout)['targets'][0]['plan']
        self.assertEqual(plan['status'], 'ready', preview.stdout)
        self.assertGreater(plan['units'], 0, preview.stdout)
        block = self.base / 'cargo-block'
        plain_env = dict(self.kache_env, FIXTURE_BLOCK=str(block))
        plain = subprocess.Popen(['cargo', 'build', '--offline'], cwd=self.repo, env=plain_env,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 120
            while not Path(str(block) + '.ready').exists() and plain.poll() is None and time.monotonic() < deadline:
                time.sleep(.05)
            self.assertTrue(Path(str(block) + '.ready').exists(), 'unwrapped Cargo did not hold its profile lock')
            clean_env = dict(plain_env)
            del clean_env['FIXTURE_BLOCK']
            clean = subprocess.run(['kache', '--json', 'clean', '--units', '--yes', str(self.repo)],
                                   cwd=self.repo, env=clean_env, capture_output=True, text=True, timeout=60, check=True)
            self.assertIn('unavailable: live output changed', clean.stdout)
            self.assertEqual(json.loads(clean.stdout)['targets'][0]['removed']['units'], 0)
            self.assertTrue(all(p.exists() for p in old), clean.stdout + clean.stderr)
        finally:
            Path(str(block) + '.done').touch()
            stdout, stderr = plain.communicate(timeout=60)
        self.assertEqual(plain.returncode, 0, stdout + stderr)
        old_bytes = sum(p.stat().st_size for p in old if p.exists())
        result = self.call('build', '--offline')
        removed = [p for p in old if not p.exists()]
        self.assertTrue(removed, 'no obsolete dependency artifact removed: ' + result.stderr)
        self.assertTrue((self.repo / 'target/debug/fixture').exists())
        fresh = self.call('build', '--offline', '-v')
        self.assertIn('Fresh fixture', fresh.stderr)
        print('obsolete artifact paths removed:', len(removed), 'artifact bytes before:', old_bytes)


if __name__ == '__main__':
    unittest.main()
