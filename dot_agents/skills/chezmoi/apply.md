# chezmoi apply

`chezmoi apply` triggers a server restart whenever config or agent files change. The current session loses its WebSocket connection and appears to hang indefinitely.

**You are running inside that server.** When `chezmoi apply` restarts it, this session will go silent.

## Triggers that cause a restart

| Trigger | What causes it | Effect |
|---------|---------------|--------|
| `run_onchange_after_restart-opencode-web.sh` | `opencode.json`, `dot_config/opencode/plugins/*`, AGENTS.md, agent files, skills, or `dot_agents/capabilities.yaml` changed | Restarts opencode-web via kickstart, then nudges interrupted sessions |
| `run_onchange_after_ensure-launchagents.sh` | `Library/LaunchAgents/*.plist.tmpl` content changed | Reloads all managed LaunchAgents, including opencode-web |

**Editing skills, AGENTS.md, or any dotfile that deploys into `~/.config/opencode/` or `~/.agents/` will trigger a restart** — the restart script now hashes all these files for change detection, so an explicit kickstart fires via chezmoi rather than relying on opencode's own file watcher.

## Auto-resume after restart

After kickstarting the server, the restart script automatically:
1. Waits for the new server to be ready (polls `/session/status`, up to 30s)
2. Queries the DB for sessions with `running` or `pending` tool parts updated in the last 10 minutes
3. Sends a nudge message to each interrupted session via the HTTP API, including context about any PTY sessions (dev servers) that were running

Sessions will pick up the nudge message when they reconnect and resume work from where they left off.

## Safe Workflow

### Option A — Apply in a PTY, then reconnect (recommended)

Run `chezmoi apply` in a background PTY so you can observe it complete, then reload the browser tab to reconnect to the new server:

```sh
# 1. Save any unsent work first (copy draft messages, note todos)

# 2. Run apply in a PTY session — this avoids blocking the current session
#    (Use the pty_spawn tool, command="chezmoi", args=["apply"])

# 3. Read PTY output — wait for "Server ready after Ns" or an error

# 4. Reload the browser tab / reconnect the TUI — the new server is up on port 4096
#    If this session was interrupted mid-task, the restart script will have already
#    sent a nudge message — just reconnect and the agent will continue automatically
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
3. If validation passes:
   - Snapshot interrupted sessions (parts with `status = running/pending` updated in last 10min)
   - `launchctl kickstart -k gui/<uid>/com.athal.opencode-web`
     - `-k` = kill existing process first, then start
     - The current server process is SIGKILLed
     - LaunchAgent `KeepAlive: true` restarts it automatically
4. New server starts on port 4096
5. Script polls until server responds (up to 30s)
6. Nudge messages sent to each interrupted session, including PTY context
7. All existing WebSocket connections are dead — clients must reconnect

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
- The restart script hashes all skill SKILL.md files, AGENTS.md, and capabilities.yaml — so any edit to those files triggers the explicit kickstart path (rather than relying on opencode's file watcher)
- The 10-minute window for interrupted session detection is intentional — it avoids nudging sessions that were idle before the restart
- PTY nudge context only surfaces non-chezmoi pty_spawn calls (dev servers, test watchers) — chezmoi apply PTY calls are filtered out
- **Adding a new `[data]` key to `.chezmoi.toml.tmpl` requires `chezmoi init` before `chezmoi apply`** — `apply` alone does not regenerate `~/.config/chezmoi/chezmoi.toml`
