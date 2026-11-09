#!/usr/bin/env python3
"""Prove the freebuff dispatcher only types into a composer it waited for.

Retire with the wrapper once freebuff has a prompt-at-launch flag or AoE ships
suggested sessions; both remove the wait-and-send loop under test.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / "dot_local/bin/executable_aoe-freebuf-session"
COMPOSER = "Enter a coding task or / for commands"

FAKE_AOE = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
root = pathlib.Path(os.environ["TEST_ROOT"])
args = sys.argv[1:]
with (root / "aoe.log").open("a") as handle:
    handle.write(json.dumps(args) + "\n")
if args[0] == "add":
    (root / "args.json").write_text(json.dumps(args))
    (root / "scratch").mkdir(exist_ok=True)
    print("ID: test-session\nPath: " + str(root / "scratch"))
elif args[:2] == ["session", "start"]:
    if os.environ.get("FAIL_START"):
        sys.exit(1)
    (root / "started").touch()
elif args[:2] == ["session", "capture"]:
    if (root / "sent").exists() and os.environ.get("PANE_AFTER_SEND"):
        print(os.environ["PANE_AFTER_SEND"])
        sys.exit(0)
    panes = json.loads(os.environ.get("PANES", "[]"))
    counter = root / "polls"
    seen = int(counter.read_text()) if counter.exists() else 0
    counter.write_text(str(seen + 1))
    print(panes[min(seen, len(panes) - 1)] if panes else "")
elif args[0] == "send":
    with (root / "sent.log").open("a") as handle:
        handle.write(json.dumps(args[2:]) + "\n")
    (root / "sent").touch()
else:
    sys.exit(64)
'''


class FreebufSessionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        aoe = self.base / "aoe"
        aoe.write_text(FAKE_AOE)
        aoe.chmod(0o700)
        self.prompt = self.base / "prompt.md"
        self.body = "Fix the flaky retry \u2713\nsecond line\n"
        self.prompt.write_text(self.body)
        self.repo = self.base / "repo"
        subprocess.run(["/usr/bin/git", "init", "-q", str(self.repo)], check=True)
        self.env = dict(os.environ, TEST_ROOT=str(self.base), AOE_BIN=str(aoe),
                        AOE_SESSION_GROUP="Attention", AOE_FREEBUF_POLL_INTERVAL="0")
        for key in ("AOE_WORKTREE_BRANCH", "AOE_NEW_BRANCH",
                    "AOE_FREEBUF_READY_TIMEOUT", "AOE_FREEBUF_COMPOSER", "PANES",
                    "PANE_AFTER_SEND", "FAIL_START"):
            self.env.pop(key, None)

    def launch(self, *extra):
        return subprocess.run([str(WRAPPER), "pr-title", str(self.prompt), *extra],
                              env=self.env, text=True, capture_output=True)

    def add_args(self):
        return json.loads((self.base / "args.json").read_text())

    def sent(self):
        path = self.base / "sent.log"
        if not path.exists():
            return []
        return [json.loads(line) for line in path.read_text().splitlines()]

    def test_waits_for_the_composer_and_sends_the_task_once(self):
        self.env["PANES"] = json.dumps(["starting freebuff", "loading models",
                                        f"\u256d\u2500\u256e\n\u2502 {COMPOSER}\n\u2570\u2500\u256f"])
        self.env["AOE_FREEBUF_READY_TIMEOUT"] = "20"
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.add_args()
        self.assertEqual(args[0], "add")
        self.assertIn("--scratch", args)
        self.assertEqual(args[args.index("--tool") + 1], "freebuff")
        self.assertEqual(args[args.index("--group") + 1], "Attention")
        self.assertIn("--extra-args=--trust-agents", args)
        self.assertIsNotNone(re.fullmatch(r"pr-title-[0-9a-f]{8}",
                                          args[args.index("--title") + 1]))
        self.assertTrue((self.base / "started").exists())
        self.assertEqual(self.sent(), [[self.body.rstrip("\n")]])

    def test_refuses_to_type_into_a_dialog(self):
        self.env["PANES"] = json.dumps(["Some questions for you", "Close \u2715"])
        self.env["AOE_FREEBUF_READY_TIMEOUT"] = "20"
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dialog", result.stderr)
        self.assertEqual(self.sent(), [])
        self.assertTrue((self.base / "started").exists())

    def test_never_sends_when_the_composer_does_not_appear(self):
        self.env["PANES"] = json.dumps(["initializing freebuff"])
        self.env["AOE_FREEBUF_READY_TIMEOUT"] = "0"
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("composer did not appear", result.stderr)
        self.assertIn(str(self.prompt), result.stderr)
        self.assertEqual(self.sent(), [])

    def test_refuses_the_composer_while_the_session_limit_blocks_it(self):
        self.env["PANES"] = json.dumps([
            "Your concurrent-session limit across CLI and Desktop is reached.",
            "Enter: take over  Esc: back to draft"])
        self.env["AOE_FREEBUF_READY_TIMEOUT"] = "20"
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("dialog", result.stderr)
        self.assertEqual(self.sent(), [])

    def test_reports_a_dialog_that_appears_after_the_send(self):
        self.env.update(PANES=json.dumps([COMPOSER]),
                        PANE_AFTER_SEND="Your concurrent-session limit across CLI and Desktop "
                                        "is reached.")
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("blocking dialog", result.stderr)
        self.assertEqual(len(self.sent()), 1)

    def test_worktree_dispatch_passes_the_branch(self):
        self.env.update(PANES=json.dumps([COMPOSER]), AOE_WORKTREE_BRANCH="attention/pr-63",
                        AOE_NEW_BRANCH="true")
        result = self.launch(str(self.repo))
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.add_args()
        self.assertEqual(args[1], str(self.repo))
        self.assertEqual(args[args.index("--worktree") + 1], "attention/pr-63")
        self.assertIn("--new-branch", args)
        self.assertEqual(len(self.sent()), 1)

    def test_group_is_configurable(self):
        self.env.update(PANES=json.dumps([COMPOSER]), AOE_SESSION_GROUP="Attention/Free")
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.add_args()[self.add_args().index("--group") + 1], "Attention/Free")

    def test_empty_prompt_never_creates_a_session(self):
        self.prompt.write_text("")
        result = self.launch()
        self.assertEqual(result.returncode, 64)
        self.assertFalse((self.base / "args.json").exists())

    def test_invalid_branch_never_creates_a_session(self):
        self.env.update(AOE_WORKTREE_BRANCH="bad branch", AOE_NEW_BRANCH="true")
        result = self.launch(str(self.repo))
        self.assertEqual(result.returncode, 64)
        self.assertFalse((self.base / "args.json").exists())

    def test_failed_start_never_sends(self):
        self.env.update(PANES=json.dumps([COMPOSER]), FAIL_START="1")
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("test-session", result.stderr)
        self.assertEqual(self.sent(), [])


if __name__ == "__main__":
    unittest.main()
