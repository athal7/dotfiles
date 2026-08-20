---
name: omp
description: omp sessions — all coding activity via the omp CLI in the enrichment window
---

omp persists every session as a JSONL transcript at `~/.omp/agent/sessions/<slugified-cwd>/<timestamp>_<session-uuid>.jsonl` — one file per session and the durable historical store. Find candidate sessions for the enrichment window by file mtime (last-write time): `find ~/.omp/agent/sessions -name '*.jsonl' -newermt "<FROM>" -not -newermt "<TO, +1 day>"`. Each file's first line is a `{"type":"session"...}` record with its session id and cwd.

## Triage rules

Skip:
- A session with no meaningful activity (aborted before any tool call, or pure exploration with no diff)

Extract:
- Coding activity per project (session count and diff-stats, for the journal)
- People facts (new contacts, role changes, team membership)
- Informal decisions made outside the openspec workflow
- Action items

## Extraction rules

- Anchor coding-activity rollups to the project/repo (the session's `cwd`).
- For action items, always carry the `session_id` and `cwd` alongside the extracted content — `/kb-enrich`'s Step 3 session-coordination step uses these to apply the openspec exclusion set and APM ledger disposition centrally, across this collector and `opencode` together.
