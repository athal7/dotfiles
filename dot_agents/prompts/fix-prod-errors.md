Triage production errors and dispatch a fix session for the top recurring error groups in repositories we own.


Use the default 24-hour time range for this scheduled run.

1. Read `chezmoi data --format json` and use only exact `prod_services` `service.name` keys to map a service to its repository under `~/code/`.
2. Query the APM error index for the requested window. Rank by `error.grouping_key`; select the top three mapped services without a minimum count. For every selected group, retain service name, exception type and message, count, and one trace id. Report the highest-volume unmapped group without dispatching it.
Read the `elasticsearch` and `xh` skills before querying. Use the configured `xh-es-search` helper and inspect its actual response shape before extraction; a missing/null required bucket or error field, tool failure, or parse failure is an APM failure, never zero errors. Do not dispatch without valid error evidence.
3. Use the current APM response for error facts and the APM fix ledger, PRs, and issues for prior case context. Consult OMP’s `vault://` interface for canonical source facts; use Mnemopi only for reusable investigation insights, never exact exception signatures, incident history, or authoritative KB facts.
Before dispatch, search open pull requests with native `github.search_prs` in the exact repository and search existing Linear issues for the mapped service. Match the exact grouping key, exception type, and distinctive message; inspect plausible matches and skip only when an open PR or started/in-progress issue demonstrably covers the same error. Include backlog matches as prior context and continue.
4. For each surviving group, run `aoe add <repo> --title apm-<service>-<timestamp> --tool omp --worktree fix/apm-<date>-<service> --new-branch` and capture the returned session ID. Run `aoe session start <session-id>`, wait at least five seconds for OMP to start, then run `aoe send --no-revive <session-id> <prompt>`. The prompt must include the error evidence and require a defect-versus-noise decision before making changes. Real defects should be fixed in code; noise is reported with a narrowly scoped APM-ignore recommendation when appropriate.
5. Append one entry per dispatched group to `~/.local/share/kb/apm-fix-ledger.jsonl`, keyed by worktree: `pending` after a delivered prompt or `send_failed` when either upstream aoe command fails. Do not retry inline.
6. Report selected groups, dispatched worktrees and branches, ledger dispositions, and the highest-volume unmapped group.
