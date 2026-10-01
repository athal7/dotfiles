Run all three daily maintenance workflows in this session.

Treat production triage, KB enrichment, and CQ quality review as independent work: a pending approval, rate limit, inaccessible source, or failed dispatch in one does not prevent eligible read-only work in another. Batch independent reads when possible; never wait on one collector before starting another independent collector. Do not retry a timed-out write until its outcome is known, and do not treat an unanswered approval as denial or permission. Resume approved work after approval; continue other eligible work while waiting. Do not substitute another source or weaken access rules to work around a denial.

At the end, read the actual todo state and report its exact completed/total count and remaining item names. A completed orchestration task means its attempted work was recorded, not that every collector succeeded or every projection scope completed. Report production dispatch outcomes, each collector terminal status and coverage state, CQ verify/status scope completeness, and CQ audit coverage separately. If any collector failed or was non-exhaustive, any scope is incomplete, the CQ audit could not run or review its full sample, or a dispatch remains pending, label the overall maintenance result partial and name the outstanding work; never call the overall run complete or successful without qualification.

Production-error triage and fix dispatch:

Triage production errors and dispatch a fix session for the top recurring error groups in repositories we own.


Use the default 24-hour time range for this scheduled run.

1. Read `chezmoi data --format json` and use only exact `prod_services` `service.name` keys to map a service to its repository under `~/code/`.
2. Query the APM error index for the requested window. Rank by `error.grouping_key`; select the top three mapped services without a minimum count. For every selected group, retain service name, exact `error.grouping_key`, exception type and message, count, and one trace id. Report the highest-volume unmapped group without dispatching it.
3. Query CQ for the exact exception signature before dispatching. Skip a group recorded as fixed unless the error recurred; carry prior triage context into a recurrence.
4. For each group surviving CQ triage, before `aoe add`, search open GitHub PRs in the exact mapped repository and existing Linear issues for the mapped service. Search for the exact `error.grouping_key`, exception type, and distinctive message; try separate searches when one query misses candidates. Inspect each plausible candidate's status, description, links/relations, and recent activity to establish whether it covers this error. A broad keyword match alone is not enough.
   Skip dispatch only if an open PR or a started/in-progress Linear issue demonstrably covers the same error; record its URL and status. A matching Backlog/Todo issue is prior context, not active implementation: include its URL, status, and relevance in the new-session prompt and continue. Do the same for uncertain matches rather than suppressing dispatch. If the group recurred after a completed fix, include the prior fix and linked follow-up context in the prompt and continue unless separate active work demonstrably covers the recurrence.
5. For each group not skipped in step 4, run `aoe add <repo> --title apm-<service>-<timestamp> --tool omp --worktree fix/apm-<date>-<service> --new-branch` and capture the returned session ID. Run `aoe session start <session-id>`, wait at least five seconds for OMP to start, then run `aoe send --no-revive <session-id> <prompt>`. If start succeeds but warns that the OMP worker did not report a session ID, inspect session capture after sending; a successful start alone does not prove delivery. If capture cannot establish delivery, report it as uncertain rather than calling the dispatch successful. The prompt must include the error evidence and relevant PR/issue URLs, statuses, and context from step 4, and require a defect-versus-noise decision before making changes. Real defects should be fixed in code; noise is reported with a narrowly scoped APM-ignore recommendation when appropriate.
6. Append one entry per dispatched group to `~/.local/share/kb/apm-fix-ledger.jsonl`, keyed by worktree: `pending` after a delivered prompt or `send_failed` when either upstream aoe command fails. Do not retry inline.
7. Report selected groups, matched PRs/issues (URLs, statuses, and relevance), skipped duplicates (URL, status, and reason), dispatched worktrees and branches, ledger dispositions, and the highest-volume unmapped group.



Knowledge-base enrichment:
`kb` is local ingestion and reconciliation state. CQ is the normal local agent index. Use `kb` as fallback when CQ has no answer or projection verification is incomplete.

`kb` with no subcommand opens an interactive TUI. Never invoke it bare from an agent session.

## CQ quality audit

Review a rotating sample of non-KB-projected CQ units. Keep KB canonical facts and projected units under the KB projection workflow; this audit must not inspect or alter projected units.

1. Run `cq-audit-candidates` and review every emitted entry's complete `insight`, `evidence`, and flags. The command uses the local CQ database read-only and selects at most five units per weekday without persistent cursor state. Require the number of emitted entries to equal `min(5, eligible_count)`; if the command fails or that count differs, report the audit as incomplete. Do not substitute direct database writes or remote CQ access.
2. Check each claim against its cited evidence and current authoritative source where available. A plausible claim or a candidate being non-projected is not evidence that it is wrong.
3. Call CQ `flag` only for a unit verified incorrect or stale, with the specific reason and evidence. Call `confirm` only when the claim was independently verified. If evidence is unavailable or ambiguous, leave the unit unchanged and report it for follow-up. Never use `propose` to rewrite an existing unit during this audit.
4. Report sample size, eligible count, reviewed count, confirmations/flags by unit ID and reason, and unresolved entries. Mark the CQ audit partial if any selected unit was not reviewed.

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

Before collection, enumerate regular `*.md` files directly under `~/.config/kb/collectors/`. These XDG collector definitions are the registry. For each file separately, read its YAML front-matter `name` with `yq --front-matter=extract -r '.name' <file>` (not one multi-file invocation); require it to match the filename stem and be unique, then load the definition. If the directory is missing or empty, or a definition has an invalid or duplicate name, report the registry prerequisite failure instead of claiming completion. `kb config get collectors` is not a supported lookup.

Every enrichment completion response MUST report every configured collector by name with one of the following statuses:
- `succeeded` — the collector ran and produced eligible evidence
- `succeeded with no eligible evidence` — the collector ran but found no extractable facts
- `failed` — the collector encountered an error or was not run; give the concrete cause in `coverage.reasons`

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

All five counts describe only what this run observed; emit each count, including a known zero, but never count unknown undiscovered or unread remainder as zero. For an unrun or partially read collector, set coverage to non-exhaustive with concrete reasons (including `not run: <cause>` when applicable). Include pagination unavailable whenever a paginated source cannot page through requested scope.
