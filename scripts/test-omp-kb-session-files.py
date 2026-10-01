#!/usr/bin/env python3
from __future__ import annotations

from datetime import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
COMMAND = ROOT / "dot_local/bin/executable_omp-kb-session-files"


class OmpKbSessionFilesTest(unittest.TestCase):
    def run_command(
        self,
        root: Path,
        from_time: str,
        to_time: str,
        *,
        tz: str = "UTC",
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(COMMAND), from_time, to_time, "--root", str(root)],
            check=False,
            capture_output=True,
            text=True,
            env={**os.environ, "TZ": tz},
        )

    @staticmethod
    def write_transcript(path: Path, *events: dict[str, str]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            "".join(json.dumps(event) + "\n" for event in events),
            encoding="utf-8",
        )

    def test_selects_transcript_by_event_dates_not_file_mtime(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            in_range = root / "project-a" / "in-range.jsonl"
            out_of_range = root / "project-b" / "out-of-range.jsonl"
            boundary = root / "project-b" / "boundary.jsonl"
            self.write_transcript(
                in_range,
                {"type": "title", "updatedAt": "2026-10-01T22:00:00Z"},
                {"type": "session", "timestamp": "2026-09-30T00:00:00Z"},
            )
            self.write_transcript(out_of_range, {"type": "message", "timestamp": "2026-10-02T00:00:00Z"})
            self.write_transcript(boundary, {"type": "message", "timestamp": "2026-10-01T23:59:59Z"})
            os.utime(in_range, (0, 0))
            os.utime(boundary, (0, 0))
            os.utime(out_of_range, (datetime.fromisoformat("2026-09-30T12:00:00+00:00").timestamp(),) * 2)

            result = self.run_command(root, "2026-09-30", "2026-10-01")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), sorted(map(str, (in_range, boundary))))

    def test_converts_event_timestamps_to_local_dates_across_dst(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            within_local_day = root / "within.jsonl"
            at_next_local_day = root / "next-day.jsonl"
            self.write_transcript(within_local_day, {"type": "message", "timestamp": "2026-03-09T04:30:00Z"})
            self.write_transcript(at_next_local_day, {"type": "message", "timestamp": "2026-03-09T05:00:00Z"})

            result = self.run_command(root, "2026-03-08", "2026-03-08", tz="America/Chicago")

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), [str(within_local_day)])

    def test_default_root_uses_xdg_data_home(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            xdg_data_home = Path(temporary)
            root = xdg_data_home / "omp/sessions/project"
            transcript = root / "session.jsonl"
            self.write_transcript(transcript, {"type": "session", "timestamp": "2026-09-30T12:00:00Z"})

            result = subprocess.run(
                [str(COMMAND), "2026-09-30", "2026-09-30"],
                check=False,
                capture_output=True,
                text=True,
                env={**os.environ, "TZ": "UTC", "XDG_DATA_HOME": str(xdg_data_home)},
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.splitlines(), [str(transcript)])

    def test_fails_instead_of_claiming_coverage_for_malformed_transcripts_or_ranges(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            malformed = root / "project" / "malformed.jsonl"
            malformed.parent.mkdir(parents=True)
            malformed.write_text('{"type":"message","timestamp":', encoding="utf-8")
            malformed_result = self.run_command(root, "2026-09-30", "2026-09-30")
            reversed_range = self.run_command(root, "2026-10-02", "2026-10-01")
            missing_root = self.run_command(root / "missing", "2026-10-01", "2026-10-01")

            self.assertNotEqual(malformed_result.returncode, 0)
            self.assertIn("invalid JSON", malformed_result.stderr)
            self.assertNotEqual(reversed_range.returncode, 0)
            self.assertIn("TO must not precede FROM", reversed_range.stderr)
            self.assertNotEqual(missing_root.returncode, 0)
            self.assertIn("omp-kb-session-files:", missing_root.stderr)


if __name__ == "__main__":
    unittest.main()
