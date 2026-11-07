#!/usr/bin/env python3
"""Exercise the real AoE host-start hook in an isolated profile and repository."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
AOE = shutil.which("aoe")


@unittest.skipUnless(AOE and shutil.which("tmux") and shutil.which("jq"), "AoE, tmux and jq are required")
class AoEStartupTest(unittest.TestCase):
    def test_worktree_start_links_pr_without_touching_main_checkout(self):
        with tempfile.TemporaryDirectory(prefix="aoe-pr-", dir="/tmp") as directory:
            root = Path(directory)
            home = root / "home"
            config = root / "config"
            bins = root / "bin"
            repo = root / "repo"
            for path in (home / ".local/bin", config / "agent-of-empires", bins, repo):
                path.mkdir(parents=True, exist_ok=True)
            env = os.environ.copy()
            for key in list(env):
                if key.startswith(("AOE_", "AGENT_OF_EMPIRES_", "XDG_")) or key in ("TMUX", "TMUX_PANE"):
                    env.pop(key, None)
            env.update(HOME=str(home), XDG_CONFIG_HOME=str(config), XDG_DATA_HOME=str(root / "data"),
                       XDG_CACHE_HOME=str(root / "cache"), XDG_STATE_HOME=str(root / "state"),
                       XDG_RUNTIME_DIR=str(root / "runtime"), AOE_TMUX_SOCKET=str(root / "tmux.sock"),
                       AOE_NO_AUTOSTART="1", PATH=f"{bins}:{env['PATH']}",
                       GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0",
                       GIT_AUTHOR_NAME="Test", GIT_AUTHOR_EMAIL="test@example.com",
                       GIT_COMMITTER_NAME="Test", GIT_COMMITTER_EMAIL="test@example.com")
            (root / "runtime").mkdir(mode=0o700)
            env["REAL_GIT"] = shutil.which("git")
            env["TEST_ORIGIN"] = str(root / "origin.git")
            git = bins / "git"
            git.write_text('''#!/bin/sh\nfor arg in "$@"; do\n  if [ "$arg" = fetch ]; then\n    exec "$REAL_GIT" -c "url.file://$TEST_ORIGIN.insteadOf=https://github.com/example/project.git" "$@"\n  fi\ndone\nexec "$REAL_GIT" "$@"\n''')
            git.chmod(0o755)

            def run(args, **kwargs):
                return subprocess.run(args, env=env, text=True, capture_output=True, timeout=40, **kwargs)

            def checked(args, **kwargs):
                result = run(args, **kwargs)
                self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
                return result.stdout.strip()

            for name in ("pr-track", "aoe-pr-track"):
                target = home / ".local/bin" / name
                shutil.copy(ROOT / f"dot_local/bin/executable_{name}", target)
                target.chmod(0o755)
            gh = bins / "gh"
            gh.write_text('''#!/bin/sh\ncase "$1 $2" in\n  "api repos/"*) jq -n --arg sha "$(git rev-parse HEAD)" '[{state:"open",head:{sha:$sha},number:42}]' | jq -r "$4" ;;\n  "pr view") printf 'feature\\texample\\tproject\\n' ;;\n  *) exit 1 ;;\nesac\n''')
            gh.chmod(0o755)
            (config / "agent-of-empires/config.toml").write_text(
                '[host_hooks]\nbefore_session = [\'"$HOME/.local/bin/aoe-pr-track"\']\n'
                f'[worktree]\npath_template = "{root}/worktrees/{{branch}}"\n')
            checked(["git", "init", "-q", "-b", "main", str(repo)])
            checked(["git", "-C", str(repo), "-c", "core.hooksPath=/dev/null", "commit", "-q", "--allow-empty", "-m", "initial"])
            checked(["git", "-C", str(repo), "branch", "feature"])
            checked(["git", "clone", "-q", "--bare", str(repo), str(root / "origin.git")])
            checked(["git", "-C", str(repo), "remote", "add", "origin", "https://github.com/example/project.git"])
            checked(["git", "-C", str(repo), "branch", "-D", "feature"])
            checked(["git", "-C", str(repo), "branch", "review"])
            # Own the foreground daemon process and an exclusive tmux socket;
            # never use `serve --stop` against a discovered or shared daemon.
            daemon = subprocess.Popen([AOE, "serve", "--core-only"], env=env,
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                socket = config / "agent-of-empires/daemon/api.sock"
                log = config / "agent-of-empires/debug.log"
                for _ in range(100):
                    if socket.exists() and log.exists() and "daemon ready" in log.read_text(errors="replace"):
                        break
                    if daemon.poll() is not None:
                        self.fail("isolated AoE daemon exited before readiness")
                    time.sleep(0.1)
                else:
                    self.fail("isolated AoE daemon did not become ready")
                created = checked([AOE, "add", str(repo), "--worktree", "review", "--title", "pr-startup-smoke",
                                   "--tool", "omp", "--cmd-override", "/bin/sleep", "--extra-args", "30"])
                match = re.search(r"^\s*ID:\s*(\S+)", created, re.MULTILINE)
                self.assertIsNotNone(match, created)
                profile = re.search(r"^\s*Profile:\s*(\S+)", created, re.MULTILINE)
                self.assertIsNotNone(profile, created)
                checkout = re.search(r"^\s*Path:\s*(.+)$", created, re.MULTILINE)
                self.assertIsNotNone(checkout, created)
                checked([AOE, "-p", profile.group(1), "session", "start", match.group(1)])
                self.assertEqual(checked(["git", "-C", checkout.group(1), "branch", "--show-current"]), "feature")
                self.assertEqual(checked(["git", "-C", str(repo), "branch", "--show-current"]), "main")
            finally:
                if "match" in locals() and match is not None and "profile" in locals() and profile is not None:
                    run([AOE, "-p", profile.group(1), "session", "stop", match.group(1)])
                if daemon.poll() is None:
                    daemon.terminate()
                    try:
                        daemon.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        daemon.kill()
                        daemon.wait(timeout=10)
                run(["tmux", "-S", str(root / "tmux.sock"), "kill-server"])


if __name__ == "__main__":
    unittest.main()
