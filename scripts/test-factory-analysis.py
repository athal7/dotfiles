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

    def tearDown(self):
        self.temp.cleanup()

    def transcript(self, name="session.jsonl"):
        path = self.root / name
        events = [
            event("2026-11-26T23:00:00Z", "session", id="s1", cwd="/private/repo", version=1),
            {"type": "title", "title": "", "source": "auto", "v": 1},
            event("2026-11-26T23:01:00Z", "message", message={
                "role": "user",
                "content": "Read ~/.agents/prompts/daily-maintenance.md and carry it out end to end. "
                           "That file is the whole task; do not ask for it to be restated.\n",
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
            assistant("2026-11-27T01:02:00Z", 120000, 3, "error"),
            assistant("2026-11-27T01:03:00Z", 121000, 1, "stop"),
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
        self.assertEqual(report["sessions"]["assistant_turns"], 3)
        self.assertEqual(report["sessions"]["user_turns"], 1)
        self.assertEqual(report["sessions"]["tool_calls"], 2)
        self.assertEqual(report["sessions"]["tool_errors"], 2)
        self.assertEqual(report["context_pressure"]["peak_prompt_tokens"], 121000)
        self.assertEqual(report["context_pressure"]["compactions"], 3)
        self.assertEqual(report["context_pressure"]["peak_non_message_tokens"], 12100)
        self.assertEqual(report["context_pressure"]["peak_tool_schema_tokens"], 6050)
        self.assertEqual(report["skills"]["observed_loads"], 1)
        self.assertEqual(report["skills"]["load_errors"], 1)
        alpha = next(item for item in report["skills"]["items"] if item["name"] == "alpha")
        self.assertEqual((alpha["observed_loads"], alpha["sessions"], alpha["load_errors"]), (1, 1, 1))
        self.assertEqual(report["maintenance"]["daily_sessions"], 1)
        self.assertEqual(report["maintenance"]["tool_errors"], 2)
        self.assertEqual(report["maintenance"]["abnormal_stops"], 1)
        self.assertEqual(report["maintenance"]["last_activity"], "2026-11-27T01:03:00Z")
        self.assertEqual({item["code"] for item in report["findings"]}, {
            "partial-coverage",
            "context-compactions",
            "tool-errors",
            "skill-load-errors",
            "maintenance-abnormal-stops",
        })
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
        self.assertEqual(after["sessions"]["assistant_turns"], 3)
        self.assertEqual(after["context_pressure"]["peak_prompt_tokens"], 121000)

    def test_clean_window_is_complete_and_empty_window_has_no_peaks(self):
        path = self.root / "clean.jsonl"
        with path.open("w") as output:
            output.write(json.dumps(event("2026-11-27T01:00:00Z", "session", id="clean")) + "\n")
            output.write(json.dumps(assistant("2026-11-27T01:01:00Z", 50000, 0, "stop")) + "\n")
        (self.skills / "beta" / "SKILL.md").unlink()
        (self.skills / "beta").rmdir()
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["schema_version"], 1)
        self.assertEqual(report["window"], {"since": SINCE, "until": UNTIL})
        self.assertEqual(report["coverage"]["status"], "complete")
        self.assertEqual(report["sessions"]["active"], 1)
        self.assertEqual(report["findings"], [])
        path.unlink()
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "complete")
        self.assertEqual(report["sessions"]["active"], 0)
        self.assertEqual(report["session_items"], [])
        self.assertIsNone(report["context_pressure"]["peak_prompt_tokens"])

    def test_tool_call_and_result_are_counted_once(self):
        path = self.root / "tools.jsonl"
        with path.open("w") as output:
            output.write(json.dumps(event("2026-11-27T01:00:00Z", "message", message={
                "role": "assistant", "stopReason": "toolUse",
                "content": [{"type": "toolCall", "id": "c1", "name": "bash", "arguments": {}}],
            })) + "\n")
            output.write(json.dumps(event("2026-11-27T01:00:01Z", "message", message={
                "role": "toolResult", "toolCallId": "c1", "toolName": "bash", "isError": True,
                "details": {"__synthetic": True, "source": "interrupt_skipped", "executed": False},
            })) + "\n")
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["sessions"]["tool_calls"], 1)
        self.assertEqual(report["sessions"]["tool_errors"], 0)
        self.assertEqual(report["sessions"]["synthetic_tool_results"], 1)

    def test_file_limit_is_explicit_and_selects_newest(self):
        old = self.root / "old.jsonl"
        new = self.root / "new.jsonl"
        old.write_text(json.dumps(event("2026-11-27T01:00:00Z", "session", id="old")) + "\n" +
                       json.dumps(assistant("2026-11-27T01:01:00Z", 90000, 0, "stop")) + "\n")
        new.write_text(json.dumps(event("2026-11-27T01:00:00Z", "session", id="new")) + "\n" +
                       json.dumps(assistant("2026-11-27T01:01:00Z", 120000, 0, "stop")) + "\n")
        start = int(datetime.fromisoformat(SINCE.replace("Z", "+00:00")).timestamp())
        os.utime(old, (start + 60, start + 60))
        os.utime(new, (start + 120, start + 120))
        result = self.run_analyzer("--max-files", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["selected_files"], 1)
        self.assertEqual(report["coverage"]["excluded_by_mtime_files"], 0)
        self.assertEqual(report["coverage"]["skipped_files"], {"file_limit": 1})
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertEqual(report["session_items"][0]["session_id"], "new")
        self.assertEqual(report["context_pressure"]["peak_prompt_tokens"], 120000)

    def test_byte_limit_marks_partial_without_losing_other_files(self):
        self.transcript("too-large.jsonl")
        self.transcript("small.jsonl")
        result = self.run_analyzer("--max-file-bytes", "20", "--max-files", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertEqual(report["coverage"]["warning_count"], 1)
        self.assertEqual(report["coverage"]["processed_files"], 1)

    def test_missing_skills_root_is_reported_as_partial(self):
        self.transcript()
        shutil.rmtree(self.skills)
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertIn("skills root not found", json.dumps(report["coverage"]["warnings"]))

    def test_skill_inventory_limit_is_inclusive_and_omissions_are_visible(self):
        (self.root / "clean.jsonl").write_text(
            json.dumps(event("2026-11-27T01:00:00Z", "session", id="clean")) + "\n" +
            json.dumps(assistant("2026-11-27T01:01:00Z", 1000, 0, "stop")) + "\n",
            encoding="utf-8",
        )
        for number in range(198):
            skill = self.skills / f"extra-{number:03}"
            skill.mkdir()
            (skill / "SKILL.md").write_text("---\nname: extra\n---\n")
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "complete")
        self.assertEqual(report["skills"]["inventory_count"], 200)
        self.assertEqual(report["skills"]["inventory_details_omitted"], 0)
        skill = self.skills / "extra-198"
        skill.mkdir()
        (skill / "SKILL.md").write_text("---\nname: extra\n---\n")
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["coverage"]["status"], "partial")
        self.assertEqual(report["skills"]["inventory_count"], 201)
        self.assertEqual(report["skills"]["inventory_details_omitted"], 1)
        self.assertIn("skill inventory details limited", json.dumps(report["coverage"]["warnings"]))

    def test_symlinked_skill_is_counted_without_reading_or_duplicating(self):
        self.transcript()
        external = self.base / "external-skill"
        external.mkdir()
        (external / "SKILL.md").write_text("---\nname: external-skill\n---\n")
        (self.skills / "external-skill").symlink_to(external, target_is_directory=True)
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["skills"]["external_inventory_count"], 1)
        self.assertNotIn("external-skill", {item["name"] for item in report["skills"]["items"]})

    def test_only_exact_cron_prompt_marks_maintenance(self):
        path = self.root / "summaries.jsonl"
        marker = ("Read ~/.agents/prompts/daily-maintenance.md and carry it out end to end. "
                  "That file is the whole task; do not ask for it to be restated.")
        events = [
            event("2026-11-27T01:00:00Z", "message", message={
                "role": "user", "content": f"### Session update\n\n**user**:\n{marker}",
            }),
            event("2026-11-27T01:01:00Z", "message", message={
                "role": "user", "synthetic": True, "attribution": "agent", "content": marker,
            }),
            event("2026-11-27T01:02:00Z", "message", message={
                "role": "assistant", "stopReason": "stop",
                "content": [{"type": "text", "text": marker}],
            }),
        ]
        path.write_text("".join(json.dumps(item) + "\n" for item in events))
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.report()
        self.assertEqual(report["maintenance"]["daily_sessions"], 0)
        self.assertEqual(report["sessions"]["active"], 1)
        self.assertEqual(report["sessions"]["user_turns"], 1)

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

    def test_invalid_window_and_missing_root_fail_without_reports(self):
        invalid = self.run_analyzer("--until", "2026-11-26T23:00:00Z")
        self.assertEqual(invalid.returncode, 1)
        self.assertFalse((self.output / "latest.json").exists())
        missing_output = self.base / "missing-output"
        command = [
            sys.executable, str(ANALYZER), "--root", str(self.base / "absent"),
            "--skills-root", str(self.skills), "--output", str(missing_output),
            "--since", SINCE, "--until", UNTIL,
        ]
        missing = subprocess.run(command, text=True, capture_output=True, cwd=self.base)
        self.assertEqual(missing.returncode, 1)
        self.assertFalse((missing_output / "latest.json").exists())

    def test_second_concurrent_run_preserves_existing_report_and_releases_lock(self):
        self.transcript()
        self.output.mkdir()
        sentinel = b'{"sentinel":true}\n'
        (self.output / "latest.json").write_bytes(sentinel)
        lock_path = self.output / ".lock"
        descriptor = os.open(lock_path, os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_analyzer()
        finally:
            os.close(descriptor)
        self.assertEqual(result.returncode, 75)
        self.assertIn("holds the output lock", result.stderr)
        self.assertEqual((self.output / "latest.json").read_bytes(), sentinel)
        result = self.run_analyzer()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report()["schema_version"], 1)


if __name__ == "__main__":
    unittest.main()
