---
description: Daily production error triage — query APM errors and dispatch worktree fix sessions
subtask: true
---

Triage production errors from Elastic APM and dispatch a fix session for the top recurring error groups.

$ARGUMENTS

Optional argument: a time-range override (e.g. `48h`). Default: last 24h.

## Skills

- **elasticsearch** — APM error query (`logs-apm.error-*`) and auth.
- **opencode** — follow `dispatch.md` for the cross-repo worktree → session → dispatch flow.

## Steps

1. **Find the top error groups.** Query APM errors over the window, aggregate by `error.grouping_key` ranked by occurrence count, and take the **top 3** — all recurring errors qualify, no minimum threshold. For each, capture `service.name`, `error.exception.type`, `error.exception.message`, the occurrence count, and a sample `trace.id`.

2. **Map service → repo.** Run `chezmoi data | jq -r '.prod_services'` for the `service.name → repo` map; the repo lives at `~/code/<repo>`. Skip any service with no mapping and note it in the report.

3. **Dispatch a fix session** for each mapped group: create a worktree on a `fix/apm-<date>-<service>` branch, then dispatch `Workflow: implement.` with the error context (service, exception type + message, occurrence count, sample trace.id). Fire-and-forget.

4. **Report** — error groups found, sessions dispatched (worktree paths + branch names), and services skipped for lack of a `prod_services` mapping.
