#!/usr/bin/env python3
"""Exercise factory analysis budgets, metrics, privacy, and report publication."""

from datetime import datetime
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ANALYZER = ROOT / "dot_local/bin/executable_factory-analysis"
SINCE = "2026-11-27T00:00:00Z"
UNTIL = "2026-11-27T02:00:00Z"

FAKE_AGENTSKILLS = '''#!/usr/bin/env python3
import pathlib
import sys
if sys.argv[1:2] != ["validate"]:
    sys.exit(64)
sys.exit(1 if pathlib.Path(sys.argv[2]).name == "beta" else 0)
'''


def event(timestamp, event_type, **fields):
    return {"timestamp": timestamp, "type": event_type, **fields}


def assistant(timestamp, prompt_tokens, epoch, stop_reason, content=None):
    return event(timestamp, "message", message={
        "role": "assistant",
        "contextSnapshot": {
            "promptTokens": prompt_tokens,
            "nonMessageTokens": prompt_tokens // 10,
            "toolSchemaTokens": prompt_tokens // 20,
            "compactionEpoch": epoch,
        },
        "stopReason": stop_reason,
        "content": content or [],
    })


class FactoryAnalysisTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.root = self.base / "sessions" / "project"
        self.root.mkdir(parents=True)
        self.skills = self.base / "skills"
        for name in ("alpha", "beta"):
            skill = self.skills / name
            skill.mkdir(parents=True)
            (skill / "SKILL.md").write_text(f"---\nname: {name}\ndescription: test\n---\n")
        self.output = self.base / "output"
        self.validator = self.base / "agentskills"
        self.validator.write_text(FAKE_AGENTSKILLS)
        self.validator.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def transcript(self, name="session.jsonl"):
        path = self.root / name
        events = [
            event("2026-11-26T23:00:00Z", "session", id="s1", cwd="/private/repo", version=1),
            {"type": "title", "title": "", "source": "auto", "v": 1},
            event("2026-11-26T23:01:00Z", "message", message={
                "role": "user",
                "content": "Read ~/.agents/prompts/daily-maintenance.md SECRET_PROMPT\n",
            }),
            assistant("2026-11-26T23:02:00Z", 999999, 0, "stop"),
            event("2026-11-27T01:00:00Z", "message", message={
                "role": "user", "content": [{"type": "text", "text": "inspect"}],
            }),
            assistant("2026-11-27T01:01:00Z", 90000, 0, "toolUse", [
                {"type": "toolCall", "id": "skill-call", "name": "read",
                 "arguments": {"path": "skill://alpha/SKILL.md"}},
                {"type": "toolCall", "id": "bash-call", "name": "bash", "arguments": {}},
            ]),
            event("2026-11-27T01:01:01Z", "message", message={
                "role": "toolResult", "toolCallId": "skill-call",
                "toolName": "read", "isError": True,
            }),
            event("2026-11-27T01:01:02Z", "message", message={
                "role": "toolResult", "toolCallId": "bash-call",
                "toolName": "bash", "isError": True,
            }),
            assistant("2026-11-27T01:02:00Z", 120000, 1, "error"),
        ]
        with path.open("w") as output:
            for item in events:
                output.write(json.dumps(item) + "\n")
            output.write("{malformed\n")
        return path

    def run_analyzer(self, *extra, output=None):
        command = [
            sys.executable, str(ANALYZER),
            "--root", str(self.root),
            "--skills-root", str(self.skills),
            "--output", str(output or self.output),
            "--agentskills", str(self.validator),
            "--since", SINCE,
            "--until", UNTIL,
            *extra,
        ]
        return subprocess.run(command, text=True, capture_output=True, cwd=self.base)

    def report(self):
        return json.loads((self.output / "latest.json").read_text())

    def test_reports_aggregate_metrics_without_transcript_content(self):
        self.transcript()
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertEqual(report["coverage"]["malformed_records"], 1)
        self.assertEqual(report["sessions"]["active"], 1)
        self.assertEqual(report["sessions"]["assistant_turns"], 2)
        self.assertEqual(report["sessions"]["user_turns"], 1)
        self.assertEqual(report["sessions"]["tool_calls"], 2)
        self.assertEqual(report["sessions"]["tool_errors"], 2)
        self.assertEqual(report["context_pressure"]["peak_prompt_tokens"], 120000)
        self.assertEqual(report["context_pressure"]["compactions"], 1)
        self.assertEqual(report["context_pressure"]["peak_non_message_tokens"], 12000)
        self.assertEqual(report["context_pressure"]["peak_tool_schema_tokens"], 6000)
        self.assertEqual(report["skills"]["observed_loads"], 1)
        self.assertEqual(report["skills"]["load_errors"], 1)
        alpha = next(item for item in report["skills"]["items"] if item["name"] == "alpha")
        self.assertEqual((alpha["observed_loads"], alpha["sessions"], alpha["load_errors"]), (1, 1, 1))
        self.assertEqual(report["skills"]["validation"]["status"], "failed")
        self.assertEqual(report["maintenance"]["daily_sessions"], 1)
        self.assertEqual(report["maintenance"]["tool_errors"], 2)
        self.assertEqual(report["maintenance"]["abnormal_stops"], 1)
        self.assertEqual(report["maintenance"]["last_activity"], "2026-11-27T01:02:00Z")
        self.assertIn("context-compactions", {item["code"] for item in report["findings"]})
        self.assertNotIn("SECRET_PROMPT", json.dumps(report))
        markdown = (self.output / "latest.md").read_text()
        self.assertNotIn("SECRET_PROMPT", markdown)
        self.assertEqual((self.output / "latest.json").stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.output / "latest.md").stat().st_mode & 0o777, 0o600)

    def test_rerun_does_not_duplicate_counts(self):
        self.transcript()
        first = self.run_analyzer()
        self.assertEqual(first.returncode, 0, first.stderr)
        before = self.report()
        second = self.run_analyzer()
        self.assertEqual(second.returncode, 0, second.stderr)
        after = self.report()
        for key in ("sessions", "context_pressure", "maintenance", "coverage"):
            self.assertEqual(before[key], after[key])

    def test_file_limit_is_explicit_and_selects_newest(self):
        self.transcript("old.jsonl")
        newest = self.transcript("new.jsonl")
        start = int(datetime.fromisoformat(SINCE.replace("Z", "+00:00")).timestamp())
        os.utime(self.root / "old.jsonl", (start + 60, start + 60))
        os.utime(newest, (start + 120, start + 120))
        result = self.run_analyzer("--max-files", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["selected_files"], 1)
        self.assertEqual(report["coverage"]["processed_files"], 1)
        self.assertEqual(report["coverage"]["skipped_files"], {"file_limit": 1})
        self.assertEqual(report["coverage"]["status"], "partial")

    def test_byte_limit_marks_partial_without_losing_other_files(self):
        self.transcript("too-large.jsonl")
        self.transcript("small.jsonl")
        result = self.run_analyzer("--max-file-bytes", "20", "--max-files", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertEqual(report["coverage"]["warning_count"], 1)
        self.assertEqual(report["coverage"]["processed_files"], 1)

    def test_missing_skills_root_is_partial_and_validation_skipped(self):
        self.transcript()
        shutil.rmtree(self.skills)
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertEqual(report["coverage"]["warning_count"], 2)
        self.assertEqual(report["skills"]["validation"]["status"], "skipped")
        self.assertIn("skills root not found", report["skills"]["validation"]["reason"])

    def test_skill_inventory_limit_is_not_silent(self):
        self.transcript()
        for number in range(199):
            skill = self.skills / f"extra-{number:03}"
            skill.mkdir()
            (skill / "SKILL.md").write_text("---\nname: extra\n---\n")
        result = self.run_analyzer("--skip-validation")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertIn("skill inventory limit reached",
                      json.dumps(report["coverage"]["warnings"]))

    def test_timestampless_message_is_partial_not_silently_ignored(self):
        path = self.root / "timestampless.jsonl"
        path.write_text(json.dumps({
            "type": "message",
            "message": {"role": "assistant", "contextSnapshot": {"promptTokens": 100},
                        "stopReason": "stop", "content": []},
        }) + "\n")
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertEqual(report["coverage"]["malformed_records"], 1)
        self.assertEqual(report["sessions"]["active"], 0)

    def test_missing_validator_is_skipped_not_reported_as_success(self):
        self.transcript()
        missing = self.base / "missing-agentskills"
        result = self.run_analyzer("--agentskills", str(missing))
        self.assertEqual(result.returncode, 0, result.stderr)
        validation = self.report()["skills"]["validation"]
        self.assertEqual(validation["status"], "skipped")
        self.assertIn("executable not found", validation["reason"])

    def test_invalid_window_and_missing_root_fail_without_reports(self):
        invalid = self.run_analyzer("--until", "2026-11-26T23:00:00Z")
        self.assertEqual(invalid.returncode, 1)
        self.assertFalse((self.output / "latest.json").exists())
        missing_output = self.base / "missing-output"
        command = [
            sys.executable, str(ANALYZER), "--root", str(self.base / "absent"),
            "--skills-root", str(self.skills), "--output", str(missing_output),
            "--since", SINCE, "--until", UNTIL, "--skip-validation",
        ]
        missing = subprocess.run(command, text=True, capture_output=True, cwd=self.base)
        self.assertEqual(missing.returncode, 1)
        self.assertFalse((missing_output / "latest.json").exists())

    def test_second_concurrent_run_exits_without_overwriting(self):
        self.output.mkdir()
        lock_path = self.output / ".lock"
        descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_analyzer()
        finally:
            os.close(descriptor)
        self.assertEqual(result.returncode, 75)
        self.assertIn("holds the output lock", result.stderr)
        self.assertFalse((self.output / "latest.json").exists())


if __name__ == "__main__":
    unittest.main()
