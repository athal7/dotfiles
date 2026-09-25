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
