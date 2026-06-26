---
name: opencode
priority: 5
authoritative_for: [coding-sessions]
description: opencode coding sessions from the local session store
---

## How to query

Query the session store SQLite database at `~/.local/share/opencode/opencode.db`.

> **Note:** The session exclusion / dedup step is handled by the orchestrator before this collector runs. By the time this collector is called, it receives a list of directories to exclude (sessions covered by archived OpenSpec changes). Apply the `NOT IN (...)` clause below.

```sql
SELECT id, directory, title, time_updated
FROM session
WHERE time_updated BETWEEN :start_ms AND :end_ms
  AND directory NOT IN ('/abs/worktree/a', '/abs/worktree/b');
-- The excluded directories are passed in by the orchestrator.
-- Only sessions NOT in the exclusion set get a transcript read.
-- For excluded sessions, the orchestrator narrates from the change's design.md/specs instead.
```

`time_updated` is epoch-milliseconds.

## What to extract

- Work done in sessions not covered by an OpenSpec archived change
- Project context, technical decisions made interactively, approaches tried

## What to skip

- Sessions whose `directory` is in the exclusion set (covered by the durable OpenSpec change artifacts — see the orchestrator's dedup step)
- Sessions with no substantive content (e.g. very short duration, no meaningful tool calls)
