---
name: chezmoi-apply
description: Run chezmoi apply safely when editing opencode config — handles the mid-session server restart that causes apparent hangs
---

## The Problem

`chezmoi apply` can trigger a server restart from **two different onchange scripts**, either of which will kill the running opencode server mid-request. The current session loses its WebSocket connection and appears to hang indefinitely.

**You are running inside that server.** When `chezmoi apply` restarts it, this session will go silent.

### Triggers that cause a restart

| Script | What it watches | Effect |
|--------|----------------|--------|
| `run_onchange_after_restart-opencode-web.sh` | `opencode.json`, `dot_config/opencode/plugins/*` | Restarts opencode-web directly |
| `run_onchange_after_ensure-launchagents.sh` | `Library/LaunchAgents/*.plist.tmpl` (glob hash) | Reloads all managed LaunchAgents, including opencode-web |

**Adding, removing, or changing any `.plist.tmpl` file triggers a restart** — not just `opencode.json`. Editing skills, commands, `AGENTS.md`, or other config files does *not* trigger a restart.

## Safe Workflow

### Option A — Apply in a PTY, then reconnect (recommended)

Run `chezmoi apply` in a background PTY so you can observe it complete, then reload the browser tab to reconnect to the new server:

```sh
# 1. Save any unsent work first (copy draft messages, note todos)

# 2. Run apply in a PTY session — this avoids blocking the current session
#    (Use the pty_spawn tool, command="chezmoi", args=["apply"])

# 3. Read PTY output — wait for "Restarted com.athal.opencode-web" or an error

# 4. Reload the browser tab / reconnect the TUI — the new server is up on port 4096
```

### Option B — Apply and accept the hang

If you don't need to observe the output:
1. Note any in-progress work (the session transcript survives in the DB)
2. Run `chezmoi apply` directly
3. The session will go silent — this is expected, not a bug
4. Reload the browser tab to reconnect

## What Actually Happens During Restart

1. `chezmoi apply` deploys changed files
2. Script validates `~/.config/opencode/opencode.json` against schema (using `check-jsonschema`)
3. If validation passes: `launchctl kickstart -k gui/<uid>/com.athal.opencode-web`
   - `-k` = kill existing process first, then start
   - The current server process is SIGKILLed
   - LaunchAgent `KeepAlive: true` restarts it automatically
4. New server starts on port 4096
5. All existing WebSocket connections are dead — clients must reconnect

If validation **fails**: the script exits 1, the running server is **not** restarted, and the old config remains active. Fix the JSON and re-apply.

## Diagnosing a Stuck/Hung State

If apply completed but the session is unresponsive and browser reload doesn't help:

```sh
# Check if the new server is running
launchctl print gui/$(id -u)/com.athal.opencode-web

# Check the server log for startup errors
tail -50 ~/Library/Logs/opencode-web.log
tail -50 ~/Library/Logs/opencode-web.error.log

# If the LaunchAgent is in a restart loop (bad config made it through):
launchctl print gui/$(id -u)/com.athal.opencode-web | grep -E 'state|last exit'
```

If the server failed to start due to a bad config that slipped past schema validation:
1. Fix `dot_config/opencode/opencode.json` in the dotfiles repo
2. Run `check-jsonschema --schemafile "https://opencode.ai/config.json" ~/.config/opencode/opencode.json` to verify
3. Run `chezmoi apply` again — this will redeploy and restart

## Notes

- Session transcript data is persisted in `~/.local/share/opencode/opencode.db` — the session is not lost, just disconnected
- The LaunchAgent `KeepAlive: true` means the server will always restart; the only failure mode is a crash loop from bad config
- `launchctl kickstart -k` is used (not `unload`/`load`) — this is intentional and correct for in-place restarts
- Changes to files other than `opencode.json` and `dot_config/opencode/plugins/*` do **not** trigger a restart (e.g., editing skills, commands, AGENTS.md)
- **Adding a new `[data]` key to `.chezmoi.toml.tmpl` requires `chezmoi init` before `chezmoi apply`** — `apply` alone does not regenerate `~/.config/chezmoi/chezmoi.toml`
