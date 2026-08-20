---
description: Triage recurring production errors and dispatch bounded OMP fix sessions
---

Triage production errors and dispatch a fix session for the top recurring error groups in repositories we own.

$ARGUMENTS

An optional argument overrides the default 24-hour time range.

1. Read `chezmoi data --format json` and use only exact `prod_services` `service.name` keys to map a service to its repository under `~/code/`.
2. Query the APM error index for the requested window. Rank by `error.grouping_key`; select the top three mapped services without a minimum count. For every selected group, retain service name, exception type and message, count, and one trace id. Report the highest-volume unmapped group without dispatching it.
3. Query CQ for the exact exception signature before dispatching. Skip a group recorded as fixed unless the error recurred; carry prior triage context into a recurrence.
4. Dispatch each surviving group with `aoe-cmd -d <repo> -n apm-<service> -w fix/apm-<date>-<service> -b <prompt>`. The prompt must include the error evidence and require a defect-versus-noise decision before any implementation. Real defects follow the implementation workflow; noise is reported with a narrowly scoped APM-ignore recommendation when appropriate.
5. Append one entry per dispatched group to `~/.local/share/kb/apm-fix-ledger.jsonl`, keyed by worktree: `pending` after a delivered prompt or `send_failed` when `aoe-cmd` fails. Do not retry inline.
6. Report selected groups, dispatched worktrees and branches, ledger dispositions, and the highest-volume unmapped group.
