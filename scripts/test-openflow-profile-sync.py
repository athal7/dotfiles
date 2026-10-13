#!/usr/bin/env python3
"""Exercise repository/OpenFlow profile sync against an isolated local API fixture."""

from __future__ import annotations

import copy
import http.server
import json
import os
import subprocess
import sys
import tempfile
import threading
import uuid
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "dot_local/bin/executable_openflow-profile-sync"


class OpenFlowFixture(http.server.BaseHTTPRequestHandler):
    profiles: dict[str, dict] = {}
    calls: list[str] = []

    def log_message(self, *_args: object) -> None:
        pass

    def respond(self, status: int, value: object) -> None:
        data = json.dumps(value).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        parsed = urlsplit(self.path)
        self.calls.append(parsed.path)
        if parsed.path == "/api/info/system":
            self.respond(200, {"app": "OpenFlow"})
        elif parsed.path == "/api/userdata":
            self.respond(200, {"profiles": [
                {"id": key, "name": value["profile"]["name"], "state": "FLOW"}
                for key, value in self.profiles.items()
            ]})
        elif parsed.path == "/api/export-profile":
            profile_id = parse_qs(parsed.query).get("profileId", [""])[0]
            if profile_id not in self.profiles:
                self.respond(404, {"detail": "missing profile"})
            else:
                self.respond(200, self.profiles[profile_id])
        else:
            self.respond(404, {"detail": "unsupported fixture route"})

    def do_POST(self) -> None:
        parsed = urlsplit(self.path)
        self.calls.append(parsed.path)
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))))
        if parsed.path == "/rpc/import-profile":
            if any(p["profile"]["name"] == body["name"] for p in self.profiles.values()):
                self.respond(409, {"detail": "duplicate name"})
                return
            profile_id = str(uuid.uuid4())
            imported = copy.deepcopy(body["data"])
            imported["profile"]["name"] = body["name"]
            self.profiles[profile_id] = imported
            self.respond(200, {"id": profile_id})
        elif parsed.path == "/rpc/rename-profile":
            profile_id = body["profileId"]
            if profile_id not in self.profiles:
                self.respond(404, {"detail": "missing profile"})
                return
            if any(key != profile_id and p["profile"]["name"] == body["name"] for key, p in self.profiles.items()):
                self.respond(409, {"detail": "duplicate name"})
                return
            self.profiles[profile_id]["profile"]["name"] = body["name"]
            self.respond(200, {"ok": True})
        elif parsed.path == "/rpc/delete-profile":
            profile_id = body["profileId"]
            if profile_id not in self.profiles or len(self.profiles) <= 1:
                self.respond(400, {"detail": "cannot delete profile"})
                return
            del self.profiles[profile_id]
            self.respond(200, {"ok": True})
        else:
            self.respond(404, {"detail": "unsupported fixture route"})


def source_fixture(root: Path, marker: str) -> Path:
    path = root / "dot_config/openflow/profiles/test-profile.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({
        "kind": "profile",
        "profile": {"name": "Repository Test Profile", "marker": marker},
        "layers": [{"srcId": "layer-source", "name": "Base", "orderId": 0}],
        "modules": {"configs": [], "configBindings": []},
    }, indent=2) + "\n", encoding="utf-8")
    return path


def run_sync(
    root: Path, state: Path, api_url: str, *, success: bool, accept_repository: bool = False,
) -> subprocess.CompletedProcess[str]:
    env = dict(os.environ, OPENFLOW_PROFILE_SYNC_STATE_DIR=str(state))
    command = [
        sys.executable, str(HELPER), "--api-url", api_url, "--source-dir", str(root),
        "sync", "--profile-file", "dot_config/openflow/profiles/test-profile.json",
    ]
    if accept_repository:
        command.append("--accept-repository")
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    assert (result.returncode == 0) == success, result.stdout + result.stderr
    return result

def run_import(root: Path, api_url: str, name: str) -> subprocess.CompletedProcess[str]:
    command = [
        sys.executable, str(HELPER), "--api-url", api_url, "--source-dir", str(root),
        "import", "--profile-file", "dot_config/openflow/profiles/test-profile.json",
        "--name", name,
    ]
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    return result


def run() -> None:
    OpenFlowFixture.profiles = {}
    OpenFlowFixture.calls = []
    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), OpenFlowFixture)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    api_url = f"http://127.0.0.1:{server.server_port}"
    try:
        with tempfile.TemporaryDirectory(prefix="openflow-profile-sync-test-") as directory:
            work = Path(directory)
            source = work / "source"
            source.mkdir()
            state = work / "state"
            source_fixture(source, "initial")

            run_sync(source, state, api_url, success=True)
            assert len(OpenFlowFixture.profiles) == 1
            original_id = next(iter(OpenFlowFixture.profiles))
            state_file = state / "repository-profiles.json"
            assert json.loads(state_file.read_text())["profiles"]["dot_config/openflow/profiles/test-profile.json"]["id"] == original_id

            run_sync(source, state, api_url, success=True)
            assert len(OpenFlowFixture.profiles) == 1

            source_fixture(source, "repository update")
            run_sync(source, state, api_url, success=True)
            assert len(OpenFlowFixture.profiles) == 1
            current_id, current = next(iter(OpenFlowFixture.profiles.items()))
            assert current_id != original_id
            assert current["profile"]["marker"] == "repository update"
            backups = list((state / "backups").glob("*.json"))
            assert len(backups) == 1
            assert json.loads(backups[0].read_text())["profile"]["marker"] == "initial"

            current["profile"]["description"] = "uncommitted GUI edit"
            source_fixture(source, "divergent repository update")
            before = copy.deepcopy(OpenFlowFixture.profiles)
            conflict = run_sync(source, state, api_url, success=False)
            assert "both changed" in conflict.stderr
            assert OpenFlowFixture.profiles == before

            run_sync(source, state, api_url, success=True, accept_repository=True)
            current_id, current = next(iter(OpenFlowFixture.profiles.items()))
            assert current["profile"]["marker"] == "divergent repository update"
            backups = sorted((state / "backups").glob("*.json"))
            assert len(backups) == 2
            assert any("uncommitted GUI edit" in backup.read_text() for backup in backups)

            collision_source = work / "collision-source"
            collision_source.mkdir()
            source_fixture(collision_source, "different unmanaged profile")
            collision_state = work / "collision-state"
            before = copy.deepcopy(OpenFlowFixture.profiles)
            collision = run_sync(collision_source, collision_state, api_url, success=False)
            assert "not managed" in collision.stderr
            assert OpenFlowFixture.profiles == before

            before_import = copy.deepcopy(OpenFlowFixture.profiles)
            calls_before_import = len(OpenFlowFixture.calls)
            run_import(source, api_url, "Repository Test Profile review")
            assert len(OpenFlowFixture.profiles) == len(before_import) + 1
            for profile_id, profile in before_import.items():
                assert OpenFlowFixture.profiles[profile_id] == profile
            candidate_id, candidate = next(
                (profile_id, profile) for profile_id, profile in OpenFlowFixture.profiles.items()
                if profile["profile"]["name"] == "Repository Test Profile review"
            )
            assert candidate["profile"]["marker"] == "divergent repository update"
            candidate_status = subprocess.run(
                [sys.executable, str(HELPER), "--api-url", api_url, "--source-dir", str(source),
                 "status", "--profile-file", "dot_config/openflow/profiles/test-profile.json",
                 "--profile-id", candidate_id],
                capture_output=True, text=True,
            )
            assert candidate_status.returncode == 0, candidate_status.stdout + candidate_status.stderr
            assert candidate_status.stdout.startswith("MATCH:")
            assert set(OpenFlowFixture.calls[calls_before_import:]) <= {
                "/api/info/system", "/api/userdata", "/rpc/import-profile", "/api/export-profile",
            }
        assert all(not ("flash" in call or "device" in call or "firmware" in call) for call in OpenFlowFixture.calls)
        print("PASS: guarded profile sync, separate review candidate, semantic MATCH, and no device routes")
    finally:
        server.shutdown()
        server.server_close()
        thread.join()


if __name__ == "__main__":
    run()
