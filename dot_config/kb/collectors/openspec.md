---
name: openspec
description: OpenSpec durable store — design decisions, rejected alternatives, and standing specs from archived /implement changes
---

Find archived OpenSpec changes within the enrichment window: glob `~/.local/share/kb/openspec/*/changes/archive/YYYY-MM-DD-*/kb-meta.yaml` for each date in the window. Each file's `worktree:` field (the absolute repo/worktree root, stamped at archive time) is the join key `/kb-enrich`'s Step 3 session-coordination step reuses to filter opencode/omp sessions covered by these durable artifacts. For each matching archive directory, read `design.md`; for each repo store, read the standing `~/.local/share/kb/openspec/<repo-slug>/specs/` for requirements active during the window.

Note: this collector reads the openspec archive directly from the filesystem — there is no `kb` CLI surface for openspec data today (`kb`'s CLI only covers `action-items`, `journal`, and `people`). Adding a `kb openspec` query command is tracked as a follow-up in the separate `kb` CLI repo (`/Users/athal/code/kb`), not in scope for this change.

## Triage rules

Skip:
- Changes outside the enrichment window (a directory whose date prefix doesn't fall in range)
- Spec content unchanged since the last run (no new standing requirement to extract this window)

Extract:
- Key decisions and rejected alternatives recorded in each `design.md` — the authoritative source of truth for `/implement` reasoning; use them rather than reconstructing from session transcripts
- Standing requirements from each `specs/` directory active during the window

## Extraction rules

- These artifacts are already in the kb via symlink; reference them, don't copy them.
- Anchor each decision to the archived change's worktree/repo so the journal's coding-activity rollup (from opencode/omp) and this collector's decision output can be cross-referenced.
