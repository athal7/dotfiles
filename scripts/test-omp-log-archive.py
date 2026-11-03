#!/usr/bin/env python3
import gzip
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

COMMAND = Path(__file__).resolve().parents[1] / "dot_local/bin/executable_omp-log-archive"


class OmpLogArchiveTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.root = self.base / "sessions"
        self.root.mkdir()
        self.source = self.root / "project" / "session" / "1.bash.log"
        self.source.parent.mkdir(parents=True)
        self.data = b"large output\x00\xff\n" * 10000
        self.source.write_bytes(self.data)
        self.destination = self.base / "backup.gz"

    def run_command(self, source=None, destination=None, apply=False):
        command = [str(COMMAND), "--root", str(self.root), str(source or self.source), str(destination or self.destination)]
        if apply:
            command.append("--apply")
        return subprocess.run(command, capture_output=True, text=True)

    def test_default_is_read_only_and_apply_is_lossless(self):
        result = self.run_command()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("dry run", result.stdout)
        self.assertFalse(self.destination.exists())
        result = self.run_command(apply=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(gzip.decompress(self.destination.read_bytes()), self.data)
        self.assertEqual(self.source.read_bytes(), self.data)
        self.assertIn(hashlib.sha256(self.data).hexdigest(), result.stdout)
        self.assertEqual(self.destination.stat().st_mode & 0o777, 0o600)

    def test_existing_destination_and_inside_store_are_not_overwritten(self):
        self.destination.write_bytes(b"keep")
        result = self.run_command(apply=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.destination.read_bytes(), b"keep")
        result = self.run_command(destination=self.root / "backup.gz", apply=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / "backup.gz").exists())
        self.assertEqual(self.source.read_bytes(), self.data)

    def test_rejects_symlinks_and_non_logs(self):
        link = self.root / "link.log"
        link.symlink_to(self.source)
        self.assertNotEqual(self.run_command(source=link, apply=True).returncode, 0)
        linked_directory = self.root / "linked"
        linked_directory.symlink_to(self.source.parent, target_is_directory=True)
        self.assertNotEqual(self.run_command(source=linked_directory / self.source.name, apply=True).returncode, 0)
        transcript = self.root / "session.jsonl"
        transcript.write_text("{}")
        self.assertNotEqual(self.run_command(source=transcript, apply=True).returncode, 0)
        self.assertFalse(self.destination.exists())

    def test_missing_and_outside_source_fail(self):
        self.assertNotEqual(self.run_command(source=self.root / "missing.log", apply=True).returncode, 0)
        outside = self.base / "outside.log"
        outside.write_bytes(b"outside")
        self.assertNotEqual(self.run_command(source=outside, apply=True).returncode, 0)
        self.assertFalse(self.destination.exists())


if __name__ == "__main__":
    unittest.main()
