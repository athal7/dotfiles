#!/usr/bin/env python3
"""Exercise workspace cleanup against real disposable Git worktrees."""

import contextlib
import importlib.machinery
import importlib.util
import io
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "dot_local/bin/executable_workspace-cleanup"
loader = importlib.machinery.SourceFileLoader("workspace_cleanup", str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
cleanup = importlib.util.module_from_spec(spec)
loader.exec_module(cleanup)


class WorktreeCleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.code = self.root / "code"
        self.repo = self.code / "sample"
        self.repo.parent.mkdir()
        self.git(self.root, "init", "-q", "-b", "main", str(self.repo))
        (self.repo / "Cargo.toml").write_text("[package]\nname = \"sample\"\nversion = \"0.1.0\"\nedition = \"2021\"\n")
        self.git(self.repo, "add", "Cargo.toml")
        self.git(self.repo, "commit", "-qm", "Rust crate")
        (self.repo / ".gitignore").write_text("/target/\n")
        self.git(self.repo, "add", ".gitignore")
        self.git(self.repo, "commit", "-qm", "base")
        self.addCleanup(patch.stopall)
        patch.object(cleanup, "CODE", self.code).start()
        self.sessions = set()
        patch.object(cleanup, "registered_sessions", side_effect=lambda: self.sessions).start()

    def git(self, cwd, *args):
        return subprocess.run(
            ["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "-C", str(cwd), *args],
            check=True, capture_output=True, text=True,
        ).stdout

    def branch(self, name, merged=False):
        path = self.root / "worktrees with spaces" / name
        path.parent.mkdir(exist_ok=True)
        self.git(self.repo, "worktree", "add", "-q", "-b", name, str(path))
        if not merged:
            (path / "branch.txt").write_text(name)
            self.git(path, "add", "branch.txt")
            self.git(path, "commit", "-qm", "unmerged branch")
        return path

    def old_target(self, path):
        target = path / "target"
        target.mkdir()
        artifact = target / "artifact"
        artifact.write_text("rebuildable output")
        old = time.time() - 45 * 86400
        os.utime(artifact, (old, old))
        os.utime(target, (old, old))
        return target

    def clean(self, dry_run):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            cleanup.worktrees(dry_run)
        return output.getvalue()

    def test_old_ignored_output_is_removed_without_losing_unmerged_branch(self):
        path = self.branch("old-artifact")
        target = self.old_target(path)
        self.assertIn(f"build artifacts: {target}", self.clean(True))
        self.assertTrue(target.exists())
        self.assertIn(f"build artifacts: {target}", self.clean(False))
        self.assertFalse(target.exists())
        self.assertTrue((path / "branch.txt").exists())
        self.assertEqual("", self.git(path, "status", "--porcelain=v1"))
        self.assertTrue(self.git(self.repo, "branch", "--list", "old-artifact").strip())

    def test_recent_dirty_registered_locked_and_tracked_outputs_are_preserved(self):
        recent = self.branch("recent")
        recent_target = self.old_target(recent)
        (recent_target / "nested").mkdir()
        (recent_target / "nested" / "new-artifact").write_text("recent work")
        dirty = self.branch("dirty")
        dirty_target = self.old_target(dirty)
        (dirty / "uncommitted.txt").write_text("preserve")
        registered = self.branch("registered")
        registered_target = self.old_target(registered)
        self.sessions.add(str(registered.resolve()))
        locked = self.branch("locked")
        locked_target = self.old_target(locked)
        self.git(self.repo, "worktree", "lock", str(locked))
        tracked = self.branch("tracked")
        tracked_target = self.old_target(tracked)
        self.git(tracked, "add", "-f", "target/artifact")
        self.git(tracked, "commit", "-qm", "tracked target")

        self.assertEqual("", self.clean(False))
        for target in (recent_target, dirty_target, registered_target, locked_target, tracked_target):
            self.assertTrue((target / "artifact").exists(), str(target))

    @unittest.skipUnless(shutil.which("lsof"), "lsof required for open-file check")
    def test_open_artifact_is_preserved(self):
        path = self.branch("open")
        target = self.old_target(path)
        with (target / "artifact").open("rb"):
            self.assertEqual("", self.clean(False))
            self.assertTrue(target.exists())

    def test_merged_worktree_is_removed_as_before(self):
        path = self.branch("merged", merged=True)
        self.assertIn(f"worktree: {path}", self.clean(False))
        self.assertFalse(path.exists())


if __name__ == "__main__":
    unittest.main()
