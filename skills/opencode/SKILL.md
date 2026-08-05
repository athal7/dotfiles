---
name: opencode
description: OpenCode's own session history and runtime internals — query the SQLite session DB, repair DB/project/worktree-picker issues, and reset the stale "Modified Files" sidebar. For aoe session dispatch (creating, sending to, attaching a live session), see the aoe skill.
license: MIT
compatibility: opencode
---

Unified skill for all OpenCode agent runtime operations. Use the reference files below for each area.

For creating, dispatching to, or attaching/capturing a live session (`aoe add`, `aoe send`, `aoe session attach`/`capture`), see the **aoe** skill instead — this skill covers only opencode's own session history, SQLite DB, and TUI-sidebar internals.

## Read-only history

For anything that doesn't need a live session — looking up a past conversation, exporting it, or resuming it — use the plain `opencode` CLI or direct SQLite reads, never a daemon:

- `opencode session list` — list sessions
- `opencode export <sessionID>` — export a session's full message/part history as JSON
- `opencode -c` / `opencode -s <sessionID>` — resume the last (or a specific) session's conversation in a fresh interactive TUI
- Direct reads against `~/.local/share/opencode/opencode.db` (SQLite, WAL mode — safe to read while a session is live)

See [sessions.md](sessions.md) for the full query cookbook.

## Reference files

- **[sessions.md](sessions.md)** — list, search, read, and continue past OpenCode sessions via the SQLite DB or CLI
- **[repair.md](repair.md)** — fix blank sessions, missing worktrees, duplicate project rows, and DB issues
- **[reset-diff.md](reset-diff.md)** — fix stale or noisy "Modified Files" sidebar after a commit, rebase, or merge
