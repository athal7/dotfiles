---
name: omp
description: omp sessions — all coding activity via the omp CLI in the enrichment window
---

OMP persists session JSONL transcripts under ${XDG_DATA_HOME:-$HOME/.local/share}/omp/sessions/<slugified-cwd>/<timestamp>_<session-uuid>.jsonl. Use the deployed omp-kb-session-files <FROM> <TO> helper to select transcripts whose event timestamps fall in the inclusive local-calendar journal window; file mtimes and session creation time do not determine activity. It reads the configured XDG data root by default and fails on missing/unreadable roots, malformed transcripts, invalid timestamps, or reversed dates. Read each returned transcript through the read tool, count a candidate as read only after inspecting enough transcript to apply the triage rules, and report any remaining unread candidates as non-exhaustive coverage.

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
