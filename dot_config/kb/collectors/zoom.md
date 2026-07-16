---
name: zoom
description: Zoom meeting summaries and transcripts — fetched by dispatching the zoom subagent
---

Dispatch the `zoom` subagent to retrieve Zoom meeting data for the enrichment window, then extract kb facts from its returned summary.

## Dispatch step

Before dispatching, resolve the local IANA timezone: `readlink /etc/localtime | sed 's#.*/zoneinfo/##'` (e.g. `America/Chicago`).

Dispatch the `zoom` subagent (`task` tool, `subagent_type: zoom`) with a prompt like:

> Search Zoom meetings from `<FROM>` to `<TO>` (ISO-8601 UTC). User timezone: `<TZ>`. For each meeting with a summary or transcript available, fetch its assets. Return a distilled summary: participants, decisions, action items (next_steps[]), and open questions. Do not dump raw transcripts.

The zoom subagent will call `search_meetings` over the window and `get_meeting_assets` per qualifying meeting, applying content priority (`summary_markdown` → `my_notes.content_markdown` → transcript items) internally.

**Gotcha:** a default `search_meetings` call can silently miss real meetings that have no AI-generated summary but DO have substantive `my_notes` content — the search must be run (or re-run) with `include_zoom_my_notes: true` to surface these. A host-only, summary-only search will report "no actionable content" for a day that actually had real meetings with decisions/action items recorded only in My Notes. Always include this flag.

## Triage rules

From the zoom subagent's returned summary, extract:

- Meeting participants and any contact info surfaced (names, roles, team membership)
- Decisions recorded in the summary — anchor each to the project or product it concerns
- Action items from `next_steps[]` — note the meeting topic and `meeting_start_time` for cross-reference
- Open questions that remain unresolved at the end of the enrichment window

## Extraction rules

- Map participants from `attendees[]` and any speaker lines to people facts.
- Anchor decisions to the project or product they concern.
- For action items, note the meeting topic and date for cross-reference.
- No local distillation step is needed — Zoom AI Companion summaries are already distilled. Use the zoom subagent's summary directly.
