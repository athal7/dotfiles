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
4. **Action items** — extract action items from the enriched window's activity. Cross-reference within the same activity data — if the activity shows you already took the action (replied to the thread, reviewed the PR, closed the issue), skip the reminder. Only create reminders for items that were not resolved within the enriched window.

## Privacy

Do not extract or store:
- Health information
- Compensation details
- Performance evaluations
- Legal or attorney-client privileged content
- Content from HR-related discussions
