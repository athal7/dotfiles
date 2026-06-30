---
name: zoom
description: Zoom meeting summaries and transcripts — fetched by dispatching the connectors subagent
---

Dispatch the `connectors` subagent to retrieve Zoom meeting data for the enrichment window, then extract kb facts from its returned summary.

## Dispatch step

Before dispatching, resolve the local IANA timezone: `readlink /etc/localtime | sed 's#.*/zoneinfo/##'` (e.g. `America/Chicago`).

Dispatch the `connectors` subagent (`task` tool, `subagent_type: connectors`) with a prompt like:

> Search Zoom meetings from `<FROM>` to `<TO>` (ISO-8601 UTC). User timezone: `<TZ>`. For each meeting with a summary or transcript available, fetch its assets. Return a distilled summary: participants, decisions, action items (next_steps[]), and open questions. Do not dump raw transcripts.

The connectors subagent will call `search_meetings` over the window and `get_meeting_assets` per qualifying meeting, applying content priority (`summary_markdown` → `my_notes.content_markdown` → transcript items) internally.

## Triage rules

From the connectors subagent's returned summary, extract:

- Meeting participants and any contact info surfaced (names, roles, team membership)
- Decisions recorded in the summary — anchor each to the project or product it concerns
- Action items from `next_steps[]` — note the meeting topic and `meeting_start_time` for cross-reference
- Open questions that remain unresolved at the end of the enrichment window

## Extraction rules

- Map participants from `attendees[]` and any speaker lines to people facts.
- Anchor decisions to the project or product they concern.
- For action items, note the meeting topic and date for cross-reference.
- No local distillation step is needed — Zoom AI Companion summaries are already distilled. Use the connectors subagent's summary directly.
