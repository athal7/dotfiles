---
name: openspec
description: OpenSpec durable store — design decisions, rejected alternatives, and standing specs from archived /implement changes
---

Find archived OpenSpec changes within the enrichment window with `kb openspec list --from YYYY-MM-DD --to YYYY-MM-DD`. Each result includes `worktree`, `branch`, `date`, `change`, `repo`, and `path`; use `worktree` as the join key `/kb-enrich`'s Step 3 session-coordination step uses to filter opencode/omp sessions covered by these durable artifacts. Read each change's design with `kb openspec show <change> --repo <repo>`; list standing requirements with `kb openspec specs list --repo <repo>` and read a requirement with `kb openspec specs show <spec> --repo <repo>`.

The kb v0.4.0 console entry point registers this read-only OpenSpec interface before invoking `main()`. Do not read archive files directly when the CLI can provide the needed metadata or content.

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
