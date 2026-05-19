---
name: chezmoi
description: Manage dotfiles via chezmoi — apply safely, destroy files, manage LaunchAgents and externals, config and template gotchas
license: MIT
compatibility: opencode
---

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
- **`chezmoi init` is destructive to the live config** — it re-renders the template from scratch. The "config file template has changed" warning from `chezmoi apply` is cosmetic when scripts are already deployed; do not run `chezmoi init` to silence it.
- **Machine-specific config lives in `.chezmoidata/local.yaml`** in the source directory — secrets manifest, calendar config, reminders, per-org config. This file is gitignored. Copy `local.yaml.example` from the repo root to `~/.local/share/chezmoi/.chezmoidata/local.yaml` to get started. The example must NOT live under `.chezmoidata/` itself — files there get merged into `chezmoi data` and would leak placeholder values into runtime.

## Gotchas

- **`.chezmoidata` values are plain data** — template expressions like `{{ .chezmoi.arch }}` inside YAML string values are not evaluated. Arch/OS logic must live in the `.tmpl` file itself.
- **`.app` bundles via `chezmoiexternal`** — use `type = "archive"` with target `"Applications/<AppName>.app"` (unique TOML key per app) and `stripComponents = 1` to strip the archive's root directory. Without `stripComponents = 1` the app ends up double-nested inside the archive's root directory. TOML does not allow duplicate keys, so each app needs its own unique target path.
- **LaunchAgent binary path changes** — after moving a binary (e.g., brew → `~/.local/bin`), `launchctl bootout` + `bootstrap` is required to pick up the new plist; `kickstart` alone is not sufficient if the service is crash-looping.
- **Updating a plist** — `chezmoi apply` only bootstraps agents that aren't loaded. To pick up plist changes on a running agent: `launchctl kickstart -k gui/$(id -u)/<label>`
- **Deleting a managed file** — `chezmoi apply` does not remove files whose source entry was deleted. Use `chezmoi destroy <target>` *before* removing the source entry — it removes both in one step. **Order matters:** if you `git rm` the source first, `chezmoi destroy` returns `not managed` and you must `rm` the deployed file manually. Note: files managed via `.chezmoiexternal.toml.tmpl` cannot be destroyed this way — chezmoi owns them; remove the external entry instead.
- **Deleting a skill** — skills in `skills/` are synced to `~/.agents/skills/` by the `run_onchange_after_sync-and-validate-skills` script, which replaces local skills wholesale. Removing a skill from `skills/` is sufficient — no `chezmoi destroy` needed. External skills (in `packages.skills`) must be removed from the list; they will be gone on the next apply.
- **"X has changed since chezmoi last wrote it" prompt** — chezmoi's persistent state SHA for that target drifted from the live file (often after an external tool rewrote it, after a template edit between sessions, or after picking `s`kip in a previous prompt). If `chezmoi diff` is empty after the prompt, the live and rendered content actually match — pick `o`verwrite (or rerun with `--force`) to resync state. Picking `s`kip leaves state stale and the prompt will reappear next apply. Recurring offender: `~/.zshrc`, occasionally rewritten by tool installers (bun, mise) at session startup.
