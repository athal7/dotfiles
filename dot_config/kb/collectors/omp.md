---
name: omp
description: omp sessions — all coding activity via the omp CLI in the enrichment window
---

OMP persists every session as a JSONL transcript at `~/.config/omp/agent/sessions/<slugified-cwd>/<timestamp>_<session-uuid>.jsonl` — one file per session and the durable historical store. Find candidate sessions for the enrichment window by file mtime (last-write time): `find ~/.config/omp/agent/sessions -name '*.jsonl' -newermt "<FROM>" -not -newermt "<TO, +1 day>"`. Each file's first line is a `{"type":"session"...}` record with its session id and cwd. Enumerate all candidates first, then process every candidate in bounded batches; count a candidate as read only after inspecting enough of its transcript to apply the triage rules. If time, context, or access prevents reading the remainder, report the discovered/read counts and non-exhaustive coverage with the concrete reason, not a completed OMP scan.

## Triage rules

Skip:
- A session with no meaningful activity (aborted before any tool call, or pure exploration with no diff)

Extract:
- Coding activity per project (session count and diff-stats, for the journal)
- People facts (new contacts, role changes, team membership)
- Informal decisions not captured in the session's own plan or task state
- Action items

## Extraction rules

- Anchor coding-activity rollups to the project/repo (the session's `cwd`).
- For action items, always carry the session_id and cwd alongside the extracted content; the scheduled daily-maintenance workflow's session coordination uses them with the APM ledger disposition centrally.
