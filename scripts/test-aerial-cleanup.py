#!/usr/bin/env python3
"""Verify downloaded-video cleanup preserves selected, open and unknown resources."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "dot_local/bin/executable_aerial-cleanup"
loader = importlib.machinery.SourceFileLoader("aerial_cleanup", str(SOURCE))
spec = importlib.util.spec_from_loader(loader.name, loader)
cleanup = importlib.util.module_from_spec(spec)
loader.exec_module(cleanup)


class AerialCleanupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.root = self.home / "Library/Application Support/com.apple.wallpaper/aerials/videos"
        self.root.mkdir(parents=True)
        self.video = self.root / "100858D2-FE01-4B70-8E2D-3FCF20AFE6B5.mov"
        self.video.write_bytes(b"downloaded video")
        self.index = self.root.parent.parent / "Store/Index.plist"
        self.index.parent.mkdir()
        self.save_saver("com.apple.wallpaper.choice.image")

    def save_saver(self, provider):
        with self.index.open("wb") as stream:
            plistlib.dump({"SystemDefault": {"Idle": {"Content": {"Choices": [{"Provider": provider}]}}}}, stream)

    def invoke(self, apply=False, selected=None, opened=None):
        selected = ["/System/Library/CoreServices/DefaultDesktop.heic"] if selected is None else selected
        opened = subprocess.CompletedProcess([], 1, "", "") if opened is None else opened
        responses = [subprocess.CompletedProcess([], 0, json.dumps(selected), ""), opened]
        argv = ["aerial-cleanup"] + (["--apply"] if apply else [])
        with patch.object(cleanup.Path, "home", return_value=self.home), patch("sys.argv", argv), patch.object(cleanup.subprocess, "run", side_effect=responses), contextlib.redirect_stdout(io.StringIO()):
            cleanup.main()

    def test_preview_keeps_download_and_apply_removes_only_video(self):
        other = self.root / "notes.txt"
        other.write_bytes(b"not a downloaded video")
        link = self.root / "009BA758-7060-4479-8EE8-FB9B40C8FB97.mov"
        link.symlink_to(other)
        self.invoke()
        self.assertEqual(self.video.read_bytes(), b"downloaded video")
        self.invoke(apply=True)
        self.assertFalse(self.video.exists())
        self.assertEqual(other.read_bytes(), b"not a downloaded video")
        self.assertTrue(link.is_symlink())

    def test_open_video_survives_apply(self):
        self.invoke(apply=True, opened=subprocess.CompletedProcess([], 0, "p123\nn" + str(self.video) + "\n", ""))
        self.assertEqual(self.video.read_bytes(), b"downloaded video")

    def test_selected_or_unavailable_desktop_preserves_video(self):
        for selected in ([str(self.video)], [], [None]):
            with self.subTest(selected=selected), self.assertRaises(SystemExit):
                self.invoke(apply=True, selected=selected)
            self.assertEqual(self.video.read_bytes(), b"downloaded video")

    def test_unreliable_open_file_check_preserves_video(self):
        for result in (subprocess.CompletedProcess([], 2, "", ""), subprocess.CompletedProcess([], 1, "", "cannot inspect")):
            with self.subTest(result=result), self.assertRaises(SystemExit):
                self.invoke(apply=True, opened=result)
            self.assertEqual(self.video.read_bytes(), b"downloaded video")

    def test_aerial_or_unknown_screensaver_preserves_downloads(self):
        for provider in ("com.apple.wallpaper.choice.aerials", "default", "unknown"):
            self.save_saver(provider)
            with self.subTest(provider=provider), self.assertRaises(SystemExit):
                self.invoke(apply=True)
            self.assertEqual(self.video.read_bytes(), b"downloaded video")

    def test_missing_or_corrupt_screensaver_settings_preserve_downloads(self):
        self.index.unlink()
        with self.assertRaises(SystemExit):
            self.invoke(apply=True)
        self.assertEqual(self.video.read_bytes(), b"downloaded video")
        self.index.write_bytes(b"not a property list")
        with self.assertRaises(SystemExit):
            self.invoke(apply=True)
        self.assertEqual(self.video.read_bytes(), b"downloaded video")


if __name__ == "__main__":
    unittest.main()
