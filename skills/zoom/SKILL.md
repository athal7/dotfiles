---
name: zoom
description: Zoom meeting summaries, transcripts, recordings, and meeting search — dispatch the connectors subagent
license: MIT
metadata:
  provides:
    - zoom
---

Zoom meeting data is available by dispatching the **`connectors` subagent** (`task` tool, `subagent_type: connectors`). The connectors subagent holds the Runlayer Zoom MCP tools and returns a distilled summary — never raw dumps.

## What connectors can retrieve

- **Meeting summaries** — AI Companion summaries and quick recaps for a date range
- **Transcripts** — timestamped transcript items when no AI summary is available
- **Action items** — `next_steps[]` from AI Companion meeting summaries
- **Participants and attendees** — names, emails, roles
- **Recordings** — cloud recording listings with file types (MP4, transcript, summary)
- **Semantic search** — search across chat or Zoom AI meeting notes

## How to dispatch

Give the connectors subagent a date window (ISO-8601 UTC) and your question. It will search for meetings, fetch assets for qualifying ones, and return a tight summary with decisions, action items, and participants extracted.
