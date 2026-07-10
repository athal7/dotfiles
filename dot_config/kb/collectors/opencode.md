---
name: opencode
description: OpenSpec durable store and OpenCode sessions — authoritative source for /implement work and all coding activity
---

## Phase 1 — Read the OpenSpec durable store

For each date in the enrichment window:

1. **Collect excluded worktrees.** Glob `~/.local/share/kb/openspec/*/changes/archive/YYYY-MM-DD-*/kb-meta.yaml` for each date in the window. Each file contains a `worktree:` field (the absolute repo/worktree root, stamped at archive time). Collect all `worktree:` values across the window into the session exclusion set.

2. **Read design artifacts.** For each matching archive directory, read `design.md` for decisions, the "why", and rejected alternatives.

3. **Read standing specs.** For each repo store, read `~/.local/share/kb/openspec/<repo-slug>/specs/` for the standing requirements that were active during the enrichment window.

## Phase 1b — Read the APM fix ledger

If `~/.local/share/kb/apm-fix-ledger.jsonl` exists, load it and compute the current disposition per `worktree` as the **last line** whose `worktree` matches — this log is append-only, so later lines supersede earlier ones for the same key:

```bash
jq -sr --arg wt "$WT" 'map(select(.worktree==$wt)) | last | .disposition // "none"' ~/.local/share/kb/apm-fix-ledger.jsonl
```

An absent file means an empty map — a benign no-op, not an error. This produces a `worktree → disposition` lookup consulted during extraction below.

## Phase 2 — Get OpenCode sessions

Use the **`opencode` skill** to query sessions whose `time_updated` falls in the enrichment window. Skip any session whose `directory` appears in the exclusion set — those sessions are covered by the durable change artifacts from Phase 1. Read transcripts only for non-excluded sessions.

**Benign failure modes:** a missed match (stale or absent `kb-meta.yaml`) wastes one transcript read; an over-match (a session in an excluded worktree that wasn't actually part of the archived change) relies on the better, distilled artifact rather than the raw transcript. Neither loses correctness.

## Extraction rules

From the OpenSpec durable store:
- Key decisions and rejected alternatives from each `design.md` — these are the authoritative source of truth for `/implement` reasoning; use them rather than reconstructing from transcripts.
- Standing requirements from each `specs/` directory.
- These artifacts are already in the kb via symlink; reference them, don't copy them.

From non-excluded OpenCode sessions:
- Coding activity per project (session count and diff-stats, for the journal)
- People facts (new contacts, role changes, team membership)
- Informal decisions made outside the openspec workflow
- Action items

For a session whose `directory` matches a ledger `worktree` (from Phase 1b), the ledger's disposition governs how it's treated instead of the general action-item rule above:
- Disposition is `filed`, `declined`, or `noise-confirmed` — already decided; do NOT re-extract it as a fresh action item. It may still count toward the journal's diff-stats/session-count rollup like any other session.
- Disposition is `pending` and the transcript shows a drafted fix and/or ticket — surface it as an action item this run: the drafted fix + ticket awaiting approve/decline. Note the `session_id` and `worktree` alongside it so `/kb-enrich`'s write-back step can resolve it once the human decides.
- Disposition is `pending` but the transcript shows no drafted fix/ticket at all (the session self-classified as noise and never reached `Workflow: implement.`) — mark it for a `noise-confirmed` write-back instead; this needs no human gate.
