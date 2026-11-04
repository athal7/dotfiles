#!/usr/bin/env python3
import concurrent.futures
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

COMMAND = Path(__file__).resolve().parents[1] / "dot_local/bin/executable_session-mailbox"


class SessionMailboxTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.env = dict(os.environ, XDG_CACHE_HOME=self.temp.name)

    def run_mailbox(self, *args, input=None):
        return subprocess.run([str(COMMAND), *args], input=input, text=True, capture_output=True, env=self.env)

    def call(self, *args, input=None):
        result = self.run_mailbox(*args, input=input)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def test_offline_delivery_reply_and_explicit_ack(self):
        sent = json.loads(self.call("send", "--from", "first", "--to", "second", "-", input="hello\nworld"))
        received = json.loads(self.call("inbox", "--for", "second"))
        self.assertEqual(received, [sent])
        self.assertEqual(received[0]["body"], "hello\nworld")
        self.assertEqual(json.loads(self.call("inbox", "--for", "first")), [])
        reply = json.loads(self.call("send", "--from", "second", "--to", "first", "--reply-to", sent["id"], "reply"))
        self.assertEqual(json.loads(self.call("inbox", "--for", "first")), [reply])
        self.assertEqual(reply["reply_to"], sent["id"])
        self.call("ack", "--for", "second", sent["id"])
        self.assertEqual(json.loads(self.call("inbox", "--for", "second")), [])
        self.assertEqual(json.loads(self.call("inbox", "--for", "second", "--all")), [sent])
        self.assertNotEqual(self.run_mailbox("ack", "--for", "first", sent["id"]).returncode, 0)

    def test_concurrent_senders_do_not_lose_messages(self):
        def send(n):
            return self.run_mailbox("send", "--from", "peer", "--to", "receiver", str(n))
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(send, range(30)))
        self.assertTrue(all(r.returncode == 0 for r in results), [r.stderr for r in results])
        messages = json.loads(self.call("inbox", "--for", "receiver"))
        self.assertEqual({m["body"] for m in messages}, {str(n) for n in range(30)})
        self.assertEqual(len({m["id"] for m in messages}), 30)

    def test_bad_ids_and_empty_messages_are_rejected(self):
        self.assertNotEqual(self.run_mailbox("send", "--from", "a", "--to", "b", " ").returncode, 0)
        self.assertNotEqual(self.run_mailbox("ack", "--for", "b", "../other").returncode, 0)


if __name__ == "__main__":
    unittest.main()
