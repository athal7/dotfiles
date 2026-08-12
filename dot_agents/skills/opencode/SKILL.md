---
name: opencode
description: Load when querying past opencode sessions from its SQLite DB, or when an opencode session DB or binary-path problem needs fixing.
license: MIT
---

Applies to the opencode runtime only; omp has its own store.

`~/.local/share/opencode/opencode.db`, SQLite in WAL mode — safe to read while a session is live. Timestamps are Unix milliseconds. Subagent sessions have a non-null `parent_id`; top-level sessions don't.

| Table | Columns |
|---|---|
| `session` | `id`, `title`, `slug`, `directory`, `project_id`, `workspace_id`, `parent_id`, `share_url`, `summary_additions`, `summary_deletions`, `summary_files`, `summary_diffs`, `time_created`, `time_updated`, `time_archived` |
| `message` | `id`, `session_id`, `data` — JSON with `role`, `agent`, `model`, `providerID`, `cost`, `tokens` |
| `part` | `id`, `message_id`, `session_id`, `data` — JSON with `type: "text"｜"tool"` |

## Session DB repair

- **Never `DELETE` a `project` row.** Duplicate rows for one worktree are normal; deleting any of them breaks the FK on `session` and every future create fails with `FOREIGN KEY constraint failed`. `UPDATE sandboxes` on all rows for that worktree instead.
- Paths in `session.directory` must be **real git worktrees** — `mkdir` alone leaves file-watching erroring on them.

## Binaries are not interchangeable

`/opt/homebrew/bin/opencode` is a **broken** Node wrapper — it walks `node_modules` from `bin/` and never finds the native binary in `libexec/`. `OPENCODE_BIN_PATH` bypasses the walk.

Use `~/.local/bin/opencode` (the chezmoi-managed GitHub release, a native Mach-O Bun binary) for anything scripted or LaunchAgent-invoked. The curl-installer binary at `~/.opencode/bin/opencode` has been seen crashing with SIGKILL. The brew formula has no `service` stanza, so `brew services` can't manage it.
