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

3. **Dispatch a triage + fix session** for each mapped group: create a worktree on a `fix/apm-<date>-<service>` branch, then dispatch a prompt carrying the error context (service, exception type + message, occurrence count, sample `trace.id`, and the request URL/transaction if available). Instruct the session to **first determine whether the error is a genuine defect or expected noise** — e.g. a 404 from a bot or bad slug, a deleted record, a probe — by reading the relevant code path and reproducing if feasible. Only if it is a real defect should it run `Workflow: implement.` to propose a fix; otherwise it should report the error as expected noise and, where appropriate, suggest an APM ignore rule (`transaction_ignore_urls` or error filtering) rather than a code change. Note that an error surfacing as a 404 may still be a real bug (e.g. our own broken asset/link causing the request) — do not dismiss by status code alone. Fire-and-forget.

4. **Report** — error groups found, sessions dispatched (worktree paths + branch names), and services skipped for lack of a `prod_services` mapping.
