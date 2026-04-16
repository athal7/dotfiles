# chezmoi apply

`chezmoi apply` may trigger an opencode server restart if plist files change (via `run_onchange_after_ensure-launchagents.sh`). The current session loses its WebSocket connection and appears to hang indefinitely.

**You are running inside that server.** When `chezmoi apply` restarts it, this session will go silent.

## Triggers that cause a restart

| Trigger | What causes it | Effect |
|---------|---------------|--------|
| `run_onchange_after_ensure-launchagents.sh` | `Library/LaunchAgents/*.plist.tmpl` content changed | Reloads all managed LaunchAgents, including opencode-web |

Skills, capabilities, and AGENTS.md are read fresh per-session — editing those does **not** trigger a restart. opencode handles config reloads itself.

## Safe Workflow

### Option A — Apply in a PTY, then reconnect (recommended)

Run `chezmoi apply` in a background PTY so you can observe it complete, then reload the browser tab to reconnect to the new server:

```sh
# 1. Run apply in a PTY session — this avoids blocking the current session
#    (Use the pty_spawn tool, command="chezmoi", args=["apply"])

# 2. Read PTY output — wait for completion

# 3. Reload the browser tab / reconnect the TUI — the new server is up on port 4096
```

### Option B — Apply and accept the hang

If you don't need to observe the output:
1. Note any in-progress work (the session transcript survives in the DB)
2. Run `chezmoi apply` directly
3. The session will go silent — this is expected, not a bug
4. Reload the browser tab to reconnect

## Diagnosing a Stuck/Hung State

If apply completed but the session is unresponsive and browser reload doesn't help:

```sh
# Check if the new server is running
launchctl print gui/$(id -u)/com.athal.opencode-web

# Check the server log for startup errors
tail -50 ~/Library/Logs/opencode-web.log
tail -50 ~/Library/Logs/opencode-web.error.log
```

## Notes

- Session transcript data is persisted in `~/.local/share/opencode/opencode.db` — the session is not lost, just disconnected
- The LaunchAgent `KeepAlive: true` means the server will always restart; the only failure mode is a crash loop from bad config
- **Adding a new `[data]` key to `.chezmoi.toml.tmpl` requires `chezmoi init` before `chezmoi apply`** — `apply` alone does not regenerate `~/.config/chezmoi/chezmoi.toml`
