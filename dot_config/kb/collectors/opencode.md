---
name: opencode
description: OpenCode sessions — all coding activity via OpenCode in the enrichment window
---

Use the **`opencode` skill** to query sessions whose `time_updated` falls in the enrichment window. Read each session's transcript.

## Triage rules

Skip:
- A session with no meaningful activity (aborted before any tool call, or pure exploration with no diff)

Extract:
- Coding activity per project (session count and diff-stats, for the journal)
- People facts (new contacts, role changes, team membership)
- Informal decisions made outside the openspec workflow
- Action items

## Extraction rules

- Anchor coding-activity rollups to the project/repo (the session's `directory`).
- For action items, always carry the `session_id` and `directory` alongside the extracted content — `/kb-enrich`'s Step 3 session-coordination step uses these to apply the openspec exclusion set and APM ledger disposition centrally, across this collector and `omp` together.
