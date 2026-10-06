The kb workflow owns canonical ingestion, reconciliation, source evidence, and access classification in its Markdown vault. OMP Mnemopi stores curated agent-learned insights only; never copy KB records into memory.

`kb` with no subcommand opens an interactive TUI. Never invoke it bare from an agent session.

## KB maintenance

| Need | Command |
|---|---|
| Reconcile people, projects, or products | `kb people|projects|products show <name>` |
| Record or inspect source journal state | `kb journal append|list|show` |

Evaluate each surfaced action against current state. Take warranted action through the appropriate workflow and approvals, then report its outcome; otherwise report why no action was needed.

For date-range resolution, use `kb journal list` in the caller's local IANA timezone; never derive the range from UTC.

## Enrichment completion reporting

A 429, 403, inaccessible attachment, or pagination failure blocks only that collector. Never retry a timed-out write until its outcome is known, bypass an approval, or substitute a less restrictive source. Record the blockage.
Start every configured collector as an independent read-only worker in one parallel batch after validating the registry. Each worker reads its collector definition and required source skill, uses only configured tools, and returns evidence plus one report record; collector workers never write KB state. Record each result independently. After every collector has a terminal status or a bounded timeout explicitly marks a stalled worker failed with non-exhaustive coverage, the KB worker reconciles all returned evidence and is the sole writer.

Read the actual todo state before reporting its completed/total count; task completion does not imply exhaustive source coverage. Overall enrichment is partial if any collector failed or was non-exhaustive, even when all attempted tasks are marked done.

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
