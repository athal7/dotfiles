---
description: Daily knowledge base enrichment — enrich profiles, journal, and decisions for each date since the last run
subtask: true
---

Run the daily knowledge base enrichment. By default enrich every date since the last run (see **Date range** below), not just today; honor an explicit date or range given in arguments instead.

$ARGUMENTS

## Step 0 — Resolve configuration

**KB_ROOT** — the knowledge base root directory. Resolve in this order:
1. The env var `KB_ROOT` if set and non-empty
2. Default: `~/.local/share/kb`

All KB reads and writes in this run use `$KB_ROOT`. Every collector file also receives `$KB_ROOT` as context.

**Re-run guard** — if today's journal file already exists at `$KB_ROOT/journal/YYYY-MM-DD.md` and `--force` was not passed in arguments, skip that date silently (log "already enriched: YYYY-MM-DD"). This prevents duplicate work from concurrent runs.

## Step 1 — Resolve the date range

Enrich the gap since the last run, not a hard single day. The most recent `$KB_ROOT/journal/YYYY-MM-DD.md` is the last-run marker: enrich each date from (last journal date + 1) through today, inclusive. This makes a Monday run sweep the trailing weekend and lets a skipped run self-heal on the next run. If no prior journal exists, default to today. An explicit date or range in `$ARGUMENTS` overrides this.

## Step 2 — Load collectors

Collectors live in `~/.config/opencode/kb-collectors/`. Each file is a self-contained markdown recipe that describes one data source. Read all `*.md` files in that directory. For each file:

1. Parse the YAML frontmatter to get `name`, `enabled`, `priority`, `authoritative_for`.
2. Skip any collector with `enabled: false`.
3. Sort remaining collectors by `priority` ascending (lower number = runs first).

The full set of collector instructions — how to query the source, triage rules, what to extract, and what to skip — is in each collector's body. Read the body now so you can apply it during collection.

Some collectors perform a **runtime enabled check** at the start of their body (e.g. verifying a token file exists before proceeding). Honor those checks: if a collector's body says to skip, log the reason and move on.

> **To add a new data source:** drop a new `.md` file into `~/.config/opencode/kb-collectors/`. No changes to this orchestrator needed. To disable a source temporarily, set `enabled: false` in its frontmatter. To configure per-machine values (token paths, org lists, workspaces), edit the relevant frontmatter field directly in the collector file.

## Step 3 — Session exclusion (cross-collector dedup)

Before running the `opencode` collector, build the session exclusion set from the `openspec` collector output (priority 0, runs first):

For each date being enriched, read `$KB_ROOT/openspec/*/changes/archive/<date>-*/kb-meta.yaml` and collect every `worktree:` value. This set is passed into the `opencode` collector as the `NOT IN (...)` list. Sessions in excluded worktrees are already covered by the durable OpenSpec change artifacts (`design.md`/specs); they do not need a transcript read.

**Benign failure modes:** a missed match (stale/absent `kb-meta.yaml`) just wastes one transcript read. An over-match just relies on the better, distilled artifact. Neither loses correctness.

## Step 4 — Run collectors

For each date in the enrichment window, run each enabled collector in priority order. Apply the collector's own query recipe, triage rules, and extraction rules exactly as written in its body. Carry the results forward into Step 5.

## Step 5 — Enrichment

### Journal
Write one cross-project rollup journal file per enriched date at `$KB_ROOT/journal/YYYY-MM-DD.md`. By construction each is THIN: feed it only from the non-excluded sessions (not covered by an archived OpenSpec change) plus git diff-stats plus Granola meeting summaries. For `/implement` work, do NOT re-narrate the OpenSpec change — reference the durable store artifacts (`design.md`/specs already in the KB via the symlink). The journal's role is the cross-project rollup and non-`/implement` activity, not a reconstruction of OpenSpec work.

### Profiles
Merge new facts into `$KB_ROOT/people/` and `$KB_ROOT/projects/` profiles. Load the `knowledge-base` skill for the canonical profile shape and merge rules. Granola is especially good for contact info (emails appear in participant lists) and role/team data — update `email:` frontmatter on person profiles whenever a new address is seen.

### Decisions
Add any decisions to the decisions log. Pull key design decisions and rejected alternatives from `$KB_ROOT/openspec/*/changes/archive/<date>-*/design.md` (READ, don't copy — the artifacts are already in the KB). Also extract decisions surfaced in Granola meeting notes. The decisions log is a distilled record anchored to its product/project, not a dump of design files or transcripts.

### Action items
Extract action items from the enriched window's activity. Cross-reference within the same activity data — if the activity shows the action was already taken (replied, reviewed, closed, appeared as done in a later meeting), skip the reminder. Only create reminders for items not resolved within the enriched window.

## Privacy

Do not extract or store:
- Health information
- Compensation details
- Performance evaluations
- Legal or attorney-client privileged content
- Content from HR-related discussions
- Content from meetings titled or tagged as confidential (e.g. "Confidential: ...")
