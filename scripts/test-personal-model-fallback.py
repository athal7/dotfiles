#!/usr/bin/env python3
"""Exercise OMP's native model fallback against a controlled provider."""
import http.server
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
import unittest


class Provider(http.server.BaseHTTPRequestHandler):
    requests = []
    fail_all = False

    def log_message(self, *_args):
        pass

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.requests.append(body["model"])
        if self.fail_all or body["model"] == "cohere/north-mini-code:free":
            payload = json.dumps({"error": {"message": "rate limited", "code": 429}}).encode()
            self.send_response(429)
            self.send_header("Retry-After", "0")
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        chunk = {"id": "test", "object": "chat.completion.chunk", "model": body["model"],
                 "choices": [{"index": 0, "delta": {"content": "fallback-ok"}, "finish_reason": "stop"}]}
        payload = ("data: " + json.dumps(chunk) + "\n\ndata: [DONE]\n\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


class FallbackTest(unittest.TestCase):
    def run_scenario(self, fail_all):
        Provider.requests = []
        Provider.fail_all = fail_all
        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Provider)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        with tempfile.TemporaryDirectory() as home:
            agent = Path(home) / ".config/omp/agent"
            agent.mkdir(parents=True)
            (agent / "models.yml").write_text(f'''providers:
  openrouter:
    baseUrl: http://127.0.0.1:{server.server_port}/v1
    api: openai-completions
    apiKey: OPENROUTER_API_KEY
    models:
      - id: cohere/north-mini-code:free
        name: primary
        contextWindow: 128000
        maxTokens: 1024
      - id: nvidia/nemotron-3.5-lightning:free
        name: fallback
        contextWindow: 128000
        maxTokens: 1024
''')
            env = {"HOME": home, "PATH": os.environ["PATH"], "PI_CONFIG_DIR": ".config/omp",
                   "PI_CODING_AGENT_DIR": str(agent), "XDG_DATA_HOME": home + "/data", "XDG_CACHE_HOME": home + "/cache",
                   "OPENROUTER_API_KEY": "test-key"}
            root = Path(__file__).resolve().parents[1]
            project = Path(home) / "repo"
            project_config = project / ".omp"
            project_config.mkdir(parents=True)
            (project_config / "config.yml").write_text("modelRoles:\n  default: openai-codex/not-personal\n")
            env["PI_CONFIG_FILES"] = str(root / "dot_config/omp/personal.yml")
            try:
                result = subprocess.run(["omp", "--no-extensions", "--no-tools",
                                         "--no-session", "--no-context-files", "--no-skills", "--no-rules",
                                         "--no-prewalk", "--no-title", "--thinking", "off", "--max-time", "60s",
                                         "-p", "hello"], cwd=project, env=env, text=True,
                                        capture_output=True, timeout=75)
            except subprocess.TimeoutExpired as exc:
                self.fail(f"OMP timed out: {exc}; requests={Provider.requests}")
        return result, list(Provider.requests)

    def test_rate_limit_walks_only_to_free_fallback(self):
        result, requests = self.run_scenario(False)
        self.assertEqual(result.returncode, 0, f"{result.stderr}\n{result.stdout}\nrequests={requests}")
        self.assertIn("fallback-ok", result.stdout)
        self.assertIn("cohere/north-mini-code:free", requests)
        self.assertEqual(requests[-1], "nvidia/nemotron-3.5-lightning:free")
        self.assertTrue(all(model.endswith(":free") for model in requests))

    def test_exhaustion_never_selects_paid_models(self):
        result, requests = self.run_scenario(True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("cohere/north-mini-code:free", requests)
        self.assertIn("nvidia/nemotron-3.5-lightning:free", requests)
        self.assertTrue(all(model.endswith(":free") for model in requests))


if __name__ == "__main__":
    unittest.main()
