---
name: zoom
description: Zoom meeting summaries and transcripts
---

Retrieve Zoom meeting data for the enrichment window, then extract kb facts from the result.

## Dispatch step

Before dispatching, resolve the local IANA timezone: `readlink /etc/localtime | sed 's#.*/zoneinfo/##'` (e.g. `America/Chicago`).

Retrieve, per the shape below:

> Index Google Calendar events from `<FROM>` to `<TO>` (ISO-8601 UTC) with `list_events`, then call `get_event` for each event to resolve its Zoom `conference.conference_id`. User timezone: `<TZ>`. For each indexed event with a `conference.conference_id`, fetch its assets. Return a distilled summary: participants, decisions, action items (`next_steps[]`), and open questions. Do not dump raw transcripts.

Google Calendar `list_events` and `get_event` are the sole index for this collector. Dedupe recurring events by both `iCalUID` and conference ID before calling Zoom `get_meeting_assets`. Do not call Zoom search, `search_describe_capabilities`, or retired `search_meetings`. A Zoom search or capability 401 must not fail a Calendar-indexed run. If Calendar access fails, mark only the Zoom collector failed and allow other collectors to continue. Record and skip individual `get_meeting_assets` 403 and 404 failures. For each qualifying meeting, apply content priority (`meeting_summary` → `my_notes.content_markdown` → transcript items) internally.

**Gotcha:** `search_meetings` is host-scoped — it silently drops any meeting athal didn't organize, even ones with real decisions/action items only in My Notes. It's retired from this collector; resolve meetings via Calendar instead (above), never call `search_meetings`. The `include_zoom_my_notes` flag an earlier version of this doc referenced doesn't exist on any current tool — don't pass it.
- **Calendar absence:** Unscheduled calls may not appear in Calendar. A valid Slack call invitation with transcript or summary is real meeting evidence and must not be classified as an absent meeting.

## Triage rules

From the result, extract:

- Meeting participants and any contact info surfaced (names, roles, team membership)
- Decisions recorded in the summary or My Notes — anchor each to the project or product it concerns
- Action items from `meeting_summary.next_steps[]` or My Notes — note the meeting topic and `start_time` for cross-reference, and who each item belongs to (My Notes items are often per-person, e.g. "Andrew: ..." vs "Brian: ...")
- Open questions that remain unresolved at the end of the enrichment window

## Extraction rules

- Map participants from `attendees[]` and any speaker lines to people facts.
- Anchor decisions to the project or product they concern.
- For action items, note the meeting topic and date for cross-reference; only athal's own open items are candidates for filing.
- No local distillation step is needed for a real summary or My Notes doc — both are already distilled. Use directly; only fall back to the raw transcript when neither exists.
