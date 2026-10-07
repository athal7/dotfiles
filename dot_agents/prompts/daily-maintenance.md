Orchestrate both daily workflows as the director. Spawn two independent workers immediately: one for production-error triage and one for knowledge-base enrichment. Give each worker its complete section and shared safety/reporting rules; workers start without this conversation. Do not perform either workflow in the director. Keep each worker on its own workstream and continue while the other is blocked. A worker turn settling is not proof of completion: inspect its full result, follow up in the same worker when evidence is missing, and reconcile outcomes before reporting. Use bounded waits so an unresponsive worker cannot hold the other hostage. Never retry an uncertain dispatch.

After spawning both workers, run `brew update` in the director, then run `brew upgrade` only if the update succeeds. Keep Homebrew maintenance independent of the workers: an update or upgrade failure must not stop their work, and a blocked worker must not prevent Homebrew maintenance. Record each command’s outcome, including an upgrade skipped after a failed update; report the Homebrew outcome separately.

Treat production triage and KB enrichment as independent work: a pending approval, rate limit, inaccessible source, or failed dispatch in one does not prevent eligible read-only work in the other. Batch independent reads when possible; never wait on one collector before starting another independent collector. Do not retry a timed-out write until its outcome is known, and do not treat an unanswered approval as denial or permission. Resume approved work after approval; continue other eligible work while waiting. Do not substitute another source or weaken access rules to work around a denial.
Before any external query, read the relevant source skill and inspect the live tool schema. Validate the actual response shape before parsing or aggregating it; malformed JSON, null where an array is required, parameter validation errors, and missing required fields are source failures, never empty evidence. Preserve successful sibling results when another call fails; use independent calls or settled-result handling, not fail-fast aggregation.

At the end, read the director's actual todo state and report its exact completed/total count and remaining item names. A completed orchestration task means its attempted work was recorded, not that every collector succeeded. Report Homebrew update and upgrade outcomes, production dispatch outcomes, and each collector's terminal status and coverage state separately. If Homebrew maintenance failed or was skipped, a worker has not finished, any collector failed or was non-exhaustive, or a dispatch remains pending, label the overall maintenance result partial and name the outstanding work; never call the overall run complete or successful without qualification. Do not mark an unfinished worker's work complete merely because another worker finished.

Production-error triage and fix dispatch:

Triage production errors and dispatch a fix session for the top recurring error groups in repositories we own.


Use the default 24-hour time range for this scheduled run.

1. Read `chezmoi data --format json` and use only exact `prod_services` `service.name` keys to map a service to its repository under `~/code/`.
2. Query the APM error index for the requested window. Rank by `error.grouping_key`; select the top three mapped services without a minimum count. For every selected group, retain service name, exact `error.grouping_key`, exception type and message, count, and one trace id. Report the highest-volume unmapped group without dispatching it.
Before querying, read the Elasticsearch and xh skills. Run xh-apm-error-groups, which uses the configured xh-es-search helper and returns compact, validated evidence for the default 24-hour window. Inspect that JSON result; if the helper fails or rejects an incomplete, timed-out, or inexact response, report an APM failure and dispatch no groups from that result.
3. Use current APM evidence for error facts and the APM fix ledger, PRs, and issues for prior case context. Consult the KB Markdown vault for canonical source facts; Mnemopi is only for reusable agent-learned investigation insights, not exact exception signatures, incident history, or authoritative KB facts.
4. Before dispatch, search open GitHub PRs in the exact mapped repository and existing Linear issues for the mapped service. Search for the exact grouping key, exception type, and distinctive message; inspect plausible matches and skip only when active work demonstrably covers the same error. Include backlog matches as prior context and continue.
Use the native `github.search_prs` tool with the exact repository owner/name; do not guess an MCP tool name or treat a failed search as no matching PRs.
   Skip dispatch only if an open PR or a started/in-progress Linear issue demonstrably covers the same error; record its URL and status. A matching Backlog/Todo issue is prior context, not active implementation: include its URL, status, and relevance in the new-session prompt and continue. Do the same for uncertain matches rather than suppressing dispatch. If the group recurred after a completed fix, include the prior fix and linked follow-up context in the prompt and continue unless separate active work demonstrably covers the recurrence.
5. For each group not skipped in step 4, run `aoe add <repo> --title apm-<service>-<timestamp> --tool omp --worktree fix/apm-<date>-<service> --new-branch` and capture the returned session ID. Run `aoe session start <session-id>`, wait at least five seconds for OMP to start, then run `aoe send --no-revive <session-id> <prompt>`. If start succeeds but warns that the OMP worker did not report a session ID, inspect session capture after sending; a successful start alone does not prove delivery. If capture cannot establish delivery, report it as uncertain rather than calling the dispatch successful. The prompt must include the error evidence and relevant PR/issue URLs, statuses, and context from step 4, and require a defect-versus-noise decision before making changes. Real defects should be fixed in code; noise is reported with a narrowly scoped APM-ignore recommendation when appropriate.
6. Append one entry per dispatched group to `~/.local/share/kb/apm-fix-ledger.jsonl`, keyed by worktree: `pending` after a delivered prompt or `send_failed` when either upstream aoe command fails. Do not retry inline.
7. Report selected groups, matched PRs/issues (URLs, statuses, and relevance), skipped duplicates (URL, status, and reason), dispatched worktrees and branches, ledger dispositions, and the highest-volume unmapped group.



Knowledge-base enrichment:
The kb workflow owns canonical ingestion, reconciliation, source evidence, and access classification in its Markdown vault. OMP Mnemopi is only for curated agent-learned insights; never copy KB records into Mnemopi.

`kb` with no subcommand opens an interactive TUI. Never invoke it bare from an agent session.

## KB maintenance

| Need | Command |
|---|---|
| Reconcile people, projects, or products | `kb people|projects|products show <name>` |
| Record or inspect source journal state | `kb journal append|list|show` |

Evaluate each surfaced action against current state. Take warranted action through the appropriate workflow and approvals, then report its outcome; otherwise report why no action was needed.

For date-range resolution, use `kb journal list` in the caller's local IANA timezone; never derive the range from UTC.

## Enrichment completion reporting
Launch independent collector reads as separate workers in one parallel batch as soon as their inputs are available. Give each worker its collector definition, required source skill, and the shared report schema. Collector workers only read sources and return evidence plus one record; record each result independently. Do not reconcile until every collector has a terminal status or a bounded timeout marks a stalled worker failed with non-exhaustive coverage. The KB worker then reconciles the results and is the sole KB writer.

Before collection, enumerate regular `*.md` files directly under `~/.config/kb/collectors/`. These XDG collector definitions are the registry. For each file separately, read its YAML front-matter `name` with `yq --front-matter=extract -r '.name' <file>` (not one multi-file invocation); require it to match the filename stem and be unique, then load the definition. If the directory is missing or empty, or a definition has an invalid or duplicate name, report the registry prerequisite failure instead of claiming completion. `kb config get collectors` is not a supported lookup.

Every enrichment completion response MUST report every configured collector by name with one of the following statuses:
- `succeeded` — the collector ran and produced eligible evidence
- `succeeded with no eligible evidence` — the collector ran but found no extractable facts
- `failed` — the collector encountered an error or was not run; give the concrete cause in `coverage.reasons`

Never claim all collectors succeeded unless every configured collector ran successfully. Omitting a collector from the report is a failure.

## Confluence

- A Decision Log page is eligible source material unless its exact content is a recorded KB write-back echo.
- Confluence publication is separate. Link the canonical KB note or source record when one exists.

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
