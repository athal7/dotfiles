#!/usr/bin/env python3
"""Exercise startup handoff through the real mailbox, with AoE as the boundary."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "dot_local/bin/executable_aoe-scheduled-session"
MAILBOX = ROOT / "dot_local/bin/executable_session-mailbox"

FAKE_AOE = r'''#!/usr/bin/env python3
import json, os, pathlib, re, shlex, subprocess, sys
root = pathlib.Path(os.environ["TEST_ROOT"])
args = sys.argv[1:]
if args[0] == "add":
    (root / "args.json").write_text(json.dumps(args))
    scratch = root / "scratch"
    scratch.mkdir(exist_ok=True)
    session_id = "invalid id" if os.environ.get("INVALID_ID") else "test-session"
    print(f"ID: {session_id}\nPath: {scratch}")
elif args[:2] == ["session", "start"]:
    (root / "started").touch()
    if os.environ.get("FAIL_START"):
        sys.exit(1)
    creation = json.loads((root / "args.json").read_text())
    if "--extra-args" in creation:
        argv = shlex.split(creation[creation.index("--extra-args") + 1])
        label = re.search(r"inbox --for (launch:[A-Fa-f0-9-]+)", argv[-1]).group(1)
        inbox = subprocess.check_output([os.environ["SESSION_MAILBOX_BIN"], "inbox", "--for", label])
        (root / "received.json").write_bytes(inbox)
    overlay = root / "scratch/.omp/mcp.json"
    if overlay.exists():
        (root / "overlay-at-start").write_text(str(overlay.stat().st_mode & 0o777))
else:
    # Any terminal send would corrupt the user's pending draft/approval.
    (root / "user-input").write_text("CORRUPTED")
    sys.exit(1)
'''


class ScheduledMailboxTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        aoe = self.base / "aoe"
        aoe.write_text(FAKE_AOE)
        aoe.chmod(0o700)
        self.input = self.base / "user-input"
        self.input.write_text("pending approval; unsent user draft")
        self.prompt = self.base / "prompt.md"
        self.body = "task with unicode ✓\n$(touch SHOULD_NOT_EXIST)\n'quoted' and \"double quoted\"\n"
        self.prompt.write_text(self.body)
        self.env = dict(os.environ, TEST_ROOT=str(self.base), AOE_BIN=str(aoe),
                        SESSION_MAILBOX_BIN=str(MAILBOX), XDG_CACHE_HOME=str(self.base / "cache"))
        for key in ("AOE_TOOL", "AOE_OMP_MODEL", "AOE_OMP_PROJECT_MCP_CONFIG",
                    "AOE_WORKTREE_BRANCH", "AOE_NEW_BRANCH"):
            self.env.pop(key, None)

    def launch(self):
        return subprocess.run([str(WRAPPER), "scheduled", str(self.prompt)],
                              env=self.env, text=True, capture_output=True, cwd=self.base)

    def stored(self):
        return [json.loads(p.read_text()) for p in (self.base / "cache/session-mailbox").glob("*/*.json")]

    def test_task_is_available_at_start_without_touching_user_input(self):
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        received = json.loads((self.base / "received.json").read_text())
        self.assertEqual([m["body"] for m in received], [self.body])
        self.assertEqual(self.input.read_text(), "pending approval; unsent user draft")
        self.assertFalse((self.base / "SHOULD_NOT_EXIST").exists())
        args = json.loads((self.base / "args.json").read_text())
        self.assertNotIn(self.body, args)
        self.assertIn(received[0]["to"], result.stdout)

    def test_failed_start_keeps_task_queued_without_retry(self):
        self.env["FAIL_START"] = "1"
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([m["body"] for m in self.stored()], [self.body])
        self.assertEqual(self.input.read_text(), "pending approval; unsent user draft")

    def test_failed_enqueue_never_starts_a_worker(self):
        cache = self.base / "cache"
        cache.mkdir()
        (cache / "session-mailbox").write_text("not a directory")
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.base / "started").exists())

    def test_freebuff_task_waits_in_mailbox_without_unsupported_startup_prompt(self):
        self.env["AOE_TOOL"] = "freebuff"
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([m["body"] for m in self.stored()], [self.body])
        self.assertFalse((self.base / "received.json").exists())
        self.assertEqual(self.input.read_text(), "pending approval; unsent user draft")
        self.assertIn("polling required", result.stdout)

    def test_overlay_is_private_and_present_before_launch(self):
        overlay = self.base / "mcp.json"
        overlay.write_text('{"mcpServers":{}}')
        self.env["AOE_OMP_PROJECT_MCP_CONFIG"] = str(overlay)
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.base / "overlay-at-start").read_text(), "384")  # 0o600

    def test_invalid_identity_cannot_start_or_dispatch(self):
        self.env["INVALID_ID"] = "1"
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.base / "started").exists())
        self.assertEqual(self.stored(), [])

    def test_linear_task_uses_same_mailbox_handoff(self):
        repo = self.base / "repo"
        subprocess.run(["/usr/bin/git", "init", "-q", str(repo)], check=True)
        self.env.update(LINEAR_ISSUE_IDENTIFIER="TASK-1", LINEAR_ISSUE_BRANCH_NAME="task-1",
                        LINEAR_WORK_DIR=str(repo), LINEAR_PROMPT=self.body,
                        AOE_SCHEDULED_SESSION_BIN=str(WRAPPER))
        result = subprocess.run([str(ROOT / "dot_local/bin/executable_linear-aoe")],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        received = json.loads((self.base / "received.json").read_text())
        self.assertEqual([m["body"] for m in received], [self.body + "\n"])
        self.assertEqual(self.input.read_text(), "pending approval; unsent user draft")

    def test_linear_invalid_branch_never_creates_or_starts_a_worker(self):
        repo = self.base / "repo"
        subprocess.run(["/usr/bin/git", "init", "-q", str(repo)], check=True)
        self.env.update(LINEAR_ISSUE_IDENTIFIER="TASK-1", LINEAR_ISSUE_BRANCH_NAME="bad branch",
                        LINEAR_WORK_DIR=str(repo), LINEAR_PROMPT=self.body,
                        AOE_SCHEDULED_SESSION_BIN=str(WRAPPER))
        result = subprocess.run([str(ROOT / "dot_local/bin/executable_linear-aoe")],
                                env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.base / "args.json").exists())
        self.assertEqual(self.stored(), [])


if __name__ == "__main__":
    unittest.main()
