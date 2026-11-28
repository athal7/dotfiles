#!/usr/bin/env python3
"""Exercise workspace and Chrome clone cleanup with disposable resources."""

import contextlib
import importlib.machinery
import importlib.util
import io
from types import SimpleNamespace
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

    def test_old_ignored_output_is_reported_but_never_removed(self):
        path = self.branch("old-artifact")
        target = self.old_target(path)
        self.assertIn(f"build artifacts (manual review only): {target}", self.clean(True))
        self.assertTrue(target.exists())
        self.assertIn(f"build artifacts (manual review only): {target}", self.clean(False))
        self.assertTrue(target.exists())
        self.assertTrue((path / "branch.txt").exists())
        self.assertEqual("", self.git(path, "status", "--porcelain=v1"))
        self.assertTrue(self.git(self.repo, "branch", "--list", "old-artifact").strip())

    def test_registered_and_dirty_sources_survive_target_cleanup(self):
        recent = self.branch("recent")
        recent_target = self.old_target(recent)
        (recent_target / "nested").mkdir()
        (recent_target / "nested" / "new-artifact").write_text("recent work")
        dirty = self.branch("dirty")
        dirty_target = self.old_target(dirty)
        dirty_source = dirty / "uncommitted.txt"
        dirty_source.write_text("preserve")
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

        output = self.clean(False)
        self.assertNotIn(str(dirty_target), output)
        self.assertIn(f"build artifacts (manual review only): {registered_target}", output)
        self.assertTrue(recent_target.exists())
        self.assertTrue(dirty_target.exists())
        self.assertTrue(dirty_source.exists())
        self.assertTrue(dirty.exists())
        self.assertTrue(registered_target.exists())
        self.assertTrue(registered.exists())
        for target in (locked_target, tracked_target):
            self.assertTrue((target / "artifact").exists(), str(target))

    def test_registered_and_dirty_sources_survive_pressure_target_cleanup(self):
        registered = self.branch("registered-pressure")
        registered_target = self.old_target(registered)
        dirty = self.branch("dirty-pressure")
        dirty_target = self.old_target(dirty)
        dirty_source = dirty / "source-change.txt"
        dirty_source.write_text("retain source")
        self.sessions.add(str(registered.resolve()))
        ten_days_ago = time.time() - 10 * 86400
        for target in (registered_target, dirty_target):
            artifact = target / "artifact"
            os.utime(artifact, (ten_days_ago, ten_days_ago))
            os.utime(target, (ten_days_ago, ten_days_ago))

        real_run = cleanup.run
        def run(*args, **kwargs):
            if str(args[0]).endswith("lsof"):
                return subprocess.CompletedProcess(args, 1, "", "")
            return real_run(*args, **kwargs)
        usage = SimpleNamespace(free=0, total=128 * 1024**3)
        with patch.object(cleanup.shutil, "disk_usage", return_value=usage), patch.object(cleanup, "run", side_effect=run):
            output = self.clean(True)
        self.assertIn(f"build artifacts (manual review only): {registered_target}", output)
        self.assertNotIn(str(dirty_target), output)
        self.assertTrue(registered_target.exists())
        self.assertTrue(dirty_target.exists())

        with patch.object(cleanup.shutil, "disk_usage", return_value=usage), patch.object(cleanup, "run", side_effect=run):
            self.clean(False)
        self.assertTrue(registered_target.exists())
        self.assertTrue(registered.exists())
        self.assertTrue(dirty_target.exists())
        self.assertTrue(dirty.exists())
        self.assertTrue(dirty_source.exists())

    @unittest.skipUnless(shutil.which("lsof"), "lsof required for open-file check")
    def test_open_registered_artifact_is_preserved(self):
        path = self.branch("open-registered")
        target = self.old_target(path)
        self.sessions.add(str(path.resolve()))
        usage = SimpleNamespace(free=0, total=128 * 1024**3)
        with patch.object(cleanup.shutil, "disk_usage", return_value=usage), (target / "artifact").open("rb"):
            self.assertEqual("", self.clean(False))
            self.assertTrue(target.exists())
            self.assertTrue(path.exists())

    def test_stale_registration_without_a_directory_is_reported_then_pruned(self):
        path = self.branch("stale")
        shutil.rmtree(path)
        output = self.clean(True)
        self.assertIn(f"stale worktree registration (missing directory): {path}", output)
        self.assertIn(str(path), self.git(self.repo, "worktree", "list"))
        self.clean(False)
        self.assertNotIn(str(path), self.git(self.repo, "worktree", "list"))
        self.assertTrue(self.git(self.repo, "branch", "--list", "stale").strip())

    def test_locked_stale_registration_is_unlocked_before_pruning(self):
        path = self.branch("locked-stale")
        self.git(self.repo, "worktree", "lock", str(path))
        shutil.rmtree(path)
        self.assertIn(f"stale worktree registration (missing directory): {path}", self.clean(True))
        self.assertIn(str(path), self.git(self.repo, "worktree", "list"))
        self.clean(False)
        self.assertNotIn(str(path), self.git(self.repo, "worktree", "list"))

    def test_apply_never_removes_a_live_worktree(self):
        path = self.branch("live", merged=True)
        self.clean(False)
        self.assertIn(str(path), self.git(self.repo, "worktree", "list"))
        self.assertTrue((path / "Cargo.toml").exists())

    def test_merged_worktree_is_reported_but_never_removed(self):
        path = self.branch("merged", merged=True)
        self.assertIn(f"worktree (manual review only): {path}", self.clean(False))
        self.assertTrue(path.exists())

    def test_registered_merged_worktree_and_target_are_preserved(self):
        path = self.branch("registered-merged", merged=True)
        target = self.old_target(path)
        self.sessions.add(str(path.resolve()))
        output = self.clean(False)
        self.assertIn(f"build artifacts (manual review only): {target}", output)
        self.assertNotIn(f"worktree (manual review only): {path}", output)
        self.assertTrue(target.exists())
        self.assertTrue((path / "Cargo.toml").exists())

    def test_missing_or_unreliable_activity_check_preserves_registered_targets(self):
        path = self.branch("activity-unknown")
        target = self.old_target(path)
        self.sessions.add(str(path.resolve()))
        real_run = cleanup.run
        usage = SimpleNamespace(free=0, total=128 * 1024**3)
        for failure in (
            FileNotFoundError("lsof"),
            subprocess.CompletedProcess([], 1, "", "cannot inspect processes"),
            subprocess.CompletedProcess([], 2, "", ""),
        ):
            def run(*args, **kwargs):
                if str(args[0]).endswith("lsof"):
                    if isinstance(failure, Exception):
                        raise failure
                    return failure
                return real_run(*args, **kwargs)
            with self.subTest(failure=failure), patch.object(cleanup.shutil, "disk_usage", return_value=usage), patch.object(cleanup, "run", side_effect=run):
                with contextlib.redirect_stderr(io.StringIO()):
                    self.clean(False)
                self.assertTrue((target / "artifact").exists())
                self.assertTrue(path.exists())

    def test_pressure_shortens_stale_age_at_fixed_free_space_trigger(self):
        gib = 1024**3
        for name, total in (("small-disk", 128 * gib), ("large-disk", 2 * 1024**4)):
            with self.subTest(name=name):
                path = self.branch(name)
                target = self.old_target(path)
                artifact = target / "artifact"
                ten_days_ago = time.time() - 10 * 86400
                os.utime(artifact, (ten_days_ago, ten_days_ago))
                os.utime(target, (ten_days_ago, ten_days_ago))
                pressure_free = cleanup.TARGET_PRESSURE_MIN_FREE_BYTES
                with patch.object(cleanup.shutil, "disk_usage", return_value=SimpleNamespace(free=pressure_free + 1, total=total)):
                    self.clean(False)
                self.assertTrue(artifact.exists())

                with patch.object(cleanup.shutil, "disk_usage", return_value=SimpleNamespace(free=pressure_free - 1, total=total)):
                    output = self.clean(True)
                self.assertIn(f"build artifacts (manual review only): {target}", output)
                self.assertTrue(artifact.exists())

                with patch.object(cleanup.shutil, "disk_usage", return_value=SimpleNamespace(free=pressure_free - 1, total=total)):
                    self.clean(False)
                self.assertTrue(target.exists())

    def test_pressure_stops_after_recovery_goal(self):
        path = self.branch("recovered")
        target = self.old_target(path)
        gib = 1024**3
        usage = [
            SimpleNamespace(free=99 * gib, total=1000 * gib),
            SimpleNamespace(free=150 * gib, total=1000 * gib),
        ]
        with patch.object(cleanup.shutil, "disk_usage", side_effect=usage):
            self.assertNotIn(f"build artifacts (manual review only): {target}", self.clean(False))
        self.assertTrue(target.exists())



@unittest.skipUnless(shutil.which("cargo") and shutil.which("kache"), "Cargo and Kache required")
class KacheTargetCleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.repo = self.base / "repo"
        (self.repo / "src").mkdir(parents=True)
        (self.repo / "Cargo.toml").write_text('[package]\nname="cleanup-fixture"\nversion="0.1.0"\nedition="2021"\n')
        (self.repo / "src/main.rs").write_text('fn main() { println!("cleanup fixture"); }\n')
        (self.repo / ".gitignore").write_text("/target/\n")
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(
            ["git", "-C", str(self.repo), "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "add", "."],
            check=True,
        )
        subprocess.run(
            ["git", "-C", str(self.repo), "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
             "commit", "-qm", "fixture"],
            check=True, capture_output=True,
        )
        self.cleanup_cwd = self.base / "cleanup"
        self.cleanup_cwd.mkdir()
        self.home = self.base / "home"
        config = self.home / ".config/kache/config.toml"
        config.parent.mkdir(parents=True)
        config.write_text("[cache]\ntarget_liveness = true\nauto_clean_orphaned_targets = false\nauto_clean_idle_targets_days = 0\n")
        self.cache = self.home / "Library/Caches/kache-test"
        self.env = {
            key: os.environ[key]
            for key in ("PATH", "RUSTUP_HOME", "SSL_CERT_FILE", "SSL_CERT_DIR")
            if key in os.environ
        }
        self.env.update(
            HOME=str(self.home),
            TMPDIR=str(self.base),
            KACHE_CONFIG=str(config),
            KACHE_CACHE_DIR=str(self.cache),
            KACHE_SOCKET_PATH=str(self.cache / "daemon.sock"),
            KACHE_HOST_CONFIG="",
            KACHE_LOCAL_ONLY="1",
            KACHE_TARGET_LIVENESS="1",
            KACHE_AUTO_CLEAN_ORPHANED_TARGETS="0",
            KACHE_AUTO_CLEAN_IDLE_TARGETS_DAYS="0",
            KACHE_AUTO_RECOVER_TARGETS="0",
            KACHE_AUTO_CLEAN_UNUSED_UNITS_DAYS="0",
        )
        self.addCleanup(self.stop_daemon)
        plain = subprocess.run(
            ["cargo", "build", "--offline"],
            cwd=self.repo, env=self.env, capture_output=True, text=True, timeout=180,
        )
        self.assertEqual(0, plain.returncode, plain.stdout + plain.stderr)
        built = subprocess.run(
            ["kache", "cargo", "--", "build", "--offline"],
            cwd=self.repo, env=self.env, capture_output=True, text=True, timeout=180,
        )
        self.assertEqual(0, built.returncode, built.stdout + built.stderr)
        self.artifact = self.repo / "target/debug/cleanup-fixture"
        self.assertTrue(self.artifact.is_file())

    def stop_daemon(self):
        subprocess.run(
            ["kache", "daemon", "stop"], cwd=self.cleanup_cwd, env=self.env,
            capture_output=True, timeout=30,
        )

    def test_pressure_preview_preserves_then_apply_reclaims_real_target(self):
        usage = SimpleNamespace(free=cleanup.TARGET_PRESSURE_MIN_FREE_BYTES - 1, total=1000 * 1024**3)
        previous = Path.cwd()
        os.chdir(self.cleanup_cwd)
        self.addCleanup(os.chdir, previous)
        with patch.dict(os.environ, self.env), \
             patch.object(cleanup, "CODE", self.base), \
             patch.object(cleanup, "TARGET_PRESSURE_STALE_DAYS", 0), \
             patch.object(cleanup.shutil, "disk_usage", return_value=usage), \
             contextlib.redirect_stdout(io.StringIO()):
            cleanup.kache_targets(True)
            self.assertTrue(self.artifact.is_file())
            cleanup.kache_targets(False)
            self.assertFalse(self.artifact.exists())


class KacheCacheCleanupTest(unittest.TestCase):
    def invoke(self, dry_run, free=None, which="/opt/homebrew/bin/kache", result=None):
        if free is None:
            free = cleanup.TARGET_PRESSURE_MIN_FREE_BYTES - 1
        if result is None:
            result = subprocess.CompletedProcess([], 0, "Would remove cache entries\n", "")
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch.object(cleanup.shutil, "disk_usage", return_value=SimpleNamespace(free=free, total=1000 * 1024**3)), \
             patch.object(cleanup.shutil, "which", return_value=which), \
             patch.object(cleanup, "run", return_value=result) as run_mock, \
             contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            cleanup.kache_cache(dry_run)
        return stdout.getvalue(), stderr.getvalue(), run_mock

    def test_healthy_disk_preserves_cache(self):
        _, error, run_mock = self.invoke(False, free=cleanup.TARGET_PRESSURE_MIN_FREE_BYTES)
        self.assertEqual("", error)
        run_mock.assert_not_called()

    def test_pressure_previews_then_applies_native_cleanup(self):
        stdout, error, run_mock = self.invoke(True)
        self.assertIn("Would remove cache entries", stdout)
        self.assertEqual("", error)
        run_mock.assert_called_once_with("kache", "clean", "--cache", "--dry-run", check=False)

        _, error, run_mock = self.invoke(False)
        self.assertEqual("", error)
        run_mock.assert_called_once_with("kache", "clean", "--cache", "--yes", check=False)

    def test_missing_kache_and_failed_cleanup_are_nonfatal(self):
        _, error, run_mock = self.invoke(False, which=None)
        self.assertIn("kache is not installed", error)
        run_mock.assert_not_called()

        failure = subprocess.CompletedProcess([], 2, "", "daemon unavailable")
        _, error, run_mock = self.invoke(False, result=failure)
        self.assertIn("daemon unavailable", error)
        run_mock.assert_called_once()

    def test_unknown_free_space_preserves_cache(self):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with patch.object(cleanup.shutil, "disk_usage", side_effect=OSError("unavailable")), \
             patch.object(cleanup, "run") as run_mock, \
             contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            cleanup.kache_cache(False)
        self.assertIn("cannot check free space", stderr.getvalue())
        run_mock.assert_not_called()


class CleanupCommandTest(unittest.TestCase):
    def test_database_cleanup_requires_explicit_opt_in(self):
        with tempfile.TemporaryDirectory() as home, \
             patch.object(Path, "home", return_value=Path(home)), \
             patch.object(cleanup, "CODE", Path(home)), \
             patch.object(cleanup, "worktrees") as worktrees, \
             patch.object(cleanup, "kache_targets") as kache_targets, \
             patch.object(cleanup, "kache_cache") as kache_cache, \
             patch.object(cleanup, "chrome_clones") as clones, \
             patch.object(cleanup, "databases") as databases, \
             patch("sys.argv", ["workspace-cleanup", "--apply"]), \
             contextlib.redirect_stdout(io.StringIO()):
            cleanup.main()
            worktrees.assert_called_once_with(False)
            kache_targets.assert_called_once_with(False)
            kache_cache.assert_called_once_with(False)
            clones.assert_called_once_with(False)
            databases.assert_not_called()
            with patch("sys.argv", ["workspace-cleanup", "--database-only", "--apply"]):
                cleanup.main()
            kache_targets.assert_called_once_with(False)
            kache_cache.assert_called_once_with(False)
            databases.assert_called_once_with(False)


class ChromeCloneCleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "com.google.Chrome.code_sign_clone"
        self.root.mkdir()
        self.stale = self.root / "code_sign_clone.stale"
        self.stale.mkdir()
        old_time = time.time() - cleanup.CHROME_CLONE_STALE_SECONDS - 60
        os.utime(self.stale, (old_time, old_time))
        self.recent = self.root / "code_sign_clone.recent"
        self.recent.mkdir()
        self.unrelated = self.root / "unrelated"
        self.unrelated.mkdir()
        self.link = self.root / "code_sign_clone.link"
        self.link.symlink_to(self.unrelated, target_is_directory=True)
        self.root_patch = patch.object(cleanup, "chrome_clone_root", return_value=self.root)
        self.root_patch.start()
        self.addCleanup(self.root_patch.stop)
        self.run_patch = patch.object(cleanup, "run", side_effect=self.no_open_files)
        self.run_mock = self.run_patch.start()
        self.addCleanup(self.run_patch.stop)

    @staticmethod
    def no_open_files(*args, **kwargs):
        return subprocess.CompletedProcess(args, 1, "", "")

    def clean(self, dry_run):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            cleanup.chrome_clones(dry_run)
        return output.getvalue()

    def test_dry_run_lists_only_old_real_clone_directories(self):
        output = self.clean(True)
        self.assertIn(f"Chrome signing clone: {self.stale}", output)
        self.assertNotIn(str(self.recent), output)
        self.assertTrue(self.stale.exists())
        self.assertTrue(self.recent.exists())
        self.assertTrue(self.unrelated.exists())
        self.assertTrue(self.link.is_symlink())

    def test_apply_removes_only_old_clone_directories(self):
        self.clean(False)
        self.assertFalse(self.stale.exists())
        self.assertTrue(self.recent.exists())
        self.assertTrue(self.unrelated.exists())
        self.assertTrue(self.link.is_symlink())

    def test_running_chrome_preserves_all_clones(self):
        self.run_mock.side_effect = [subprocess.CompletedProcess([], 0, "123 Google Chrome\n", "")]
        error = io.StringIO()
        with contextlib.redirect_stderr(error):
            self.clean(False)
        self.assertIn("Google Chrome is running", error.getvalue())
        self.assertTrue(self.stale.exists())
        self.assertEqual(self.run_mock.call_count, 1)

    def test_open_or_uncheckable_clone_tree_is_preserved(self):
        for lsof_result in (
            subprocess.CompletedProcess([], 0, "COMMAND PID NAME\nChrome 123 bundle", ""),
            subprocess.CompletedProcess([], 2, "", "lsof failed"),
        ):
            with self.subTest(returncode=lsof_result.returncode):
                self.run_mock.reset_mock()
                self.run_mock.side_effect = [self.no_open_files([], check=False), lsof_result]
                error = io.StringIO()
                with contextlib.redirect_stderr(error):
                    self.clean(False)
                self.assertIn("cannot establish that the clone tree is unused", error.getvalue())
                self.assertTrue(self.stale.exists())


if __name__ == "__main__":
    unittest.main()
