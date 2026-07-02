---
description: Knowledge base enrichment — enrich profiles, journal, and decisions for each date since the last run
subtask: true
---

Enrich the knowledge base for every date since the last run. An explicit date or range given in arguments overrides.

$ARGUMENTS

## Step 1 — Resolve date range

The most recent `~/.local/share/kb/journal/YYYY-MM-DD.md` is the last-run marker: enrich each date from (last journal date + 1) through today, inclusive. This makes a Monday run sweep the trailing weekend and lets a skipped run self-heal on the next run. If no prior journal exists, default to today. An explicit date or range in arguments overrides this.

## Step 2 — Load collectors

Collectors live at `~/.config/kb/collectors/*.md`. Which collectors run is determined by the enabled list in chezmoi local config:

```
chezmoi data --format json | jq -r '.kb.collectors[]'
```

Run only the listed collectors. If the key is absent, log "kb.collectors not configured" and stop.

## Step 3 — Run each collector

For each enabled collector, apply its embedded query recipe and triage/extraction rules against the resolved date window. Collectors are independent — run them in any order. The opencode collector handles its own internal openspec→exclusion→sessions sequencing.

## Step 4 — Write outputs

After all collectors have run, write the enrichment outputs:

1. **Journal** — write one cross-project rollup journal file per enriched date at `~/.local/share/kb/journal/YYYY-MM-DD.md`, each with diff stats. By construction each is THIN: feed it only from the NON-excluded sessions (those not covered by an archived change) plus git diff-stats. For `/implement` work, do NOT re-narrate the openspec change — reference the durable store artifacts (`design.md`/specs already in the kb via the symlink). The journal's role is the cross-project rollup + non-`/implement` activity, not a reconstruction of openspec work.
2. **Profiles** — merge new facts into knowledge-base people and project profiles at `~/.local/share/kb/people/` and `~/.local/share/kb/projects/`.
3. **Decisions** — add any decisions to the decisions log. Pull key design decisions and rejected alternatives from the durable store's `~/.local/share/kb/openspec/*/changes/archive/YYYY-MM-DD-*/design.md` (READ, don't copy — the artifacts are already in the kb via the symlink). The decisions log is a distilled record anchored to its product/project, not a dump of the design files.
4. **Action items** — extract action items from the enriched window's activity, then dedup against that same activity: if it shows you already took the action (replied to the thread, reviewed the PR, closed the issue), drop it. Only items still open at window end proceed.

   Before filing anything, check for pre-existing duplicates against the likely destination's actual current state — not just this window's activity. A prior run, or activity outside this window, may have already resolved or already filed the same item. For a reminder, this means checking all reminders (open and completed), not only open ones — a completed item won't appear under "open" but still means it's already handled. Match by the item's source URL first, falling back to a close title match. Skip filing anything for a matched item.

   For each surviving item, use your own judgement about where it belongs rather than following a fixed rule: a reminder, a tracked issue, a message to the relevant person or channel, or nothing at all if it's already tracked at its source (e.g. an open issue surfaced by a collector — filing a duplicate would be worse than a reminder). Weigh the item's nature, which collector surfaced it, and where similar items already live. Default to a reminder when nothing more fitting applies. Preserve the item's source URL in whatever gets filed so it stays traceable back to its origin. Creating a tracked issue or sending a message are remote-system writes — list what you intend to file and where, and confirm before creating them; a reminder is local and can be created directly. Respect the Privacy rules below — never route privacy-excluded content to a shared destination.

## Privacy

Do not extract or store:
- Health information
- Compensation details
- Performance evaluations
- Legal or attorney-client privileged content
- Content from HR-related discussions
