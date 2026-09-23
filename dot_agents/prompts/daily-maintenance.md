Run both daily maintenance workflows in this session.

Production-error triage and fix dispatch:

Triage production errors and dispatch a fix session for the top recurring error groups in repositories we own.


Use the default 24-hour time range for this scheduled run.

1. Read `chezmoi data --format json` and use only exact `prod_services` `service.name` keys to map a service to its repository under `~/code/`.
2. Query the APM error index for the requested window. Rank by `error.grouping_key`; select the top three mapped services without a minimum count. For every selected group, retain service name, exception type and message, count, and one trace id. Report the highest-volume unmapped group without dispatching it.
3. Query CQ for the exact exception signature before dispatching. Skip a group recorded as fixed unless the error recurred; carry prior triage context into a recurrence.
4. For each surviving group, run `aoe add <repo> --title apm-<service>-<timestamp> --tool omp --worktree fix/apm-<date>-<service> --new-branch` and capture the returned session ID. Run `aoe session start <session-id>`, wait at least five seconds for OMP to start, then run `aoe send --no-revive <session-id> <prompt>`. The prompt must include the error evidence and require a defect-versus-noise decision before making changes. Real defects should be fixed in code; noise is reported with a narrowly scoped APM-ignore recommendation when appropriate.
5. Append one entry per dispatched group to `~/.local/share/kb/apm-fix-ledger.jsonl`, keyed by worktree: `pending` after a delivered prompt or `send_failed` when either upstream aoe command fails. Do not retry inline.
6. Report selected groups, dispatched worktrees and branches, ledger dispositions, and the highest-volume unmapped group.



Knowledge-base enrichment:
`kb` is local ingestion and reconciliation state. CQ is the normal local agent index. Use `kb` as fallback when CQ has no answer or projection verification is incomplete.

`kb` with no subcommand opens an interactive TUI. Never invoke it bare from an agent session.

## KB maintenance

| Need | Command |
|---|---|
| Reconcile people, projects, or products | `kb people|projects|products show <name>` |
| Record or inspect source journal state | `kb journal append|list|show` |
| Reconcile existing local action items | `kb action-items list`, then `complete`/`progress`/`todo <line_no>` |

For date-range resolution, use `kb journal list` in the caller's local IANA timezone; never derive the range from UTC.

## Projection operation

- Keep canonical facts, source evidence, deduplication, and publication disposition in KB state. Do not use a direct SQLite write for CQ or KB state.
- Collectors provide source identity, fingerprint, and access classification. KB performs projection after enrichment presents the complete plan.
- Capability gate: call `/usr/bin/env -u CQ_ADDR -u CQ_API_KEY CQ_LOCAL_DB_PATH="$HOME/.local/share/cq/local.db" kb cq projection plan --help`. If it fails, stop projection safely and retain KB fallback.
- Normal projection: run upstream `plan --output <owner-only-plan.json>`. Backfill: run upstream `backfill --output <owner-only-plan.json>`. Add `--authorization-policy all-local-agents` only when `kb.local_projection.all_local_agents_authorized_for_classified_content` is true.
- After the plan is complete, run upstream `approve <plan.json> --output <owner-only-approved.json>`, `apply <approved.json>`, `verify`, then `status` in the same isolated environment.
- Upstream owns authorization digests, ledger mutation, recovery, replacement, completion, and verification. Do not emulate these mechanics.
- Upstream fails closed for records whose access classification needs authorization. Never use `CQ_ADDR`, `CQ_API_KEY`, `cq auth`, `cq drain`, another database, credentials, secrets, or access-incompatible content.
- CQ verification is complete only when upstream `status` and `verify` report the relevant scope complete. Until every backfill scope completes, retain KB fallback.
## Enrichment completion reporting

Every enrichment completion response MUST report every configured collector by name with one of the following statuses:
- `succeeded` — the collector ran and produced eligible evidence
- `succeeded with no eligible evidence` — the collector ran but found no extractable facts
- `failed` — the collector encountered an error

Never claim all collectors succeeded unless every configured collector ran successfully. Omitting a collector from the report is a failure.

## Confluence

- A Decision Log page is eligible source material unless its exact content is a recorded KB write-back echo.
- Confluence publication is separate. Link a CQ KU only when one exists.

## Limits

- A person usually exists under an alias. Resolve before adding a profile.
- Journal stats come from git, not from ephemeral session stores.
- Never invent a source URL or workspace slug.
- A project is a durable service or named workstream. A feature or issue belongs under its parent.
## Collector reporting

For every configured collector, emit exactly one report record:

```yaml
collector: <configured collector name>
terminal_status: succeeded | succeeded with no eligible evidence | failed
coverage:
  state: exhaustive | non-exhaustive | not-applicable
  reasons: [<concrete reason>]
counts:
  discovered: <integer>
  read: <integer>
  eligible_evidence: <integer>
  known_omitted: <integer>
  out_of_allowlist: <integer>
```

Always emit every count, including zero. Set coverage to non-exhaustive and include pagination unavailable whenever a paginated source cannot page through requested scope. Never invent counts for unknown unread remainder.
