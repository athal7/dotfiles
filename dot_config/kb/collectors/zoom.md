---
name: zoom
description: Zoom meeting summaries and transcripts
---

Retrieve Zoom meeting data for the enrichment window, then extract kb facts from the result.

## Dispatch step

Before dispatching, resolve the local IANA timezone: `readlink /etc/localtime | sed 's#.*/zoneinfo/##'` (e.g. `America/Chicago`).

Retrieve, per the shape below:

> Enumerate every accessible Google Calendar with `list_calendars`. For each calendar, index events from `<FROM>` to `<TO>` (ISO-8601 UTC) with `list_events`, then call `get_event` for every candidate to resolve its occurrence/start identity and Zoom `conference.conference_id`. User timezone: `<TZ>`. Deduplicate only duplicate-calendar mirrors of the same resolved occurrence: require matching `iCalUID`, occurrence/start identity, and `conference.conference_id`; retain distinct occurrences in the same series even when their iCalUID or conference ID match. Call `get_meeting_assets` only for a resolved occurrence. Retain an asset only when its `meeting_id` equals the resolved event's `conference.conference_id` and its `meeting_start_time` exactly equals the resolved event's `start.dateTime`. The only permitted time exception is a recurring-series start time that is recorded as the explicit provenance-caveated fallback below. Reject every other asset for another recurring occurrence. Return a distilled summary: participants, decisions, action items (`next_steps[]`), and open questions. Do not dump raw transcripts.

Google Calendar `list_calendars`, `list_events`, and `get_event` are the sole index for this collector: enumerate every accessible calendar and resolve every candidate event before matching Zoom assets. Dedupe only calendar mirrors with the same resolved occurrence identity (`iCalUID` plus occurrence/start identity) and conference ID; never collapse different occurrences solely because their iCalUID or conference ID matches. After retrieval, retain assets only when both `meeting_id`/`conference.conference_id` and `meeting_start_time`/`start.dateTime` match the resolved Calendar occurrence. The only allowed mismatch is the explicit recurring-series start-time fallback in the occurrence identity rules below. Do not call Zoom search, `search_describe_capabilities`, or retired `search_meetings`; do not add a search or capability fallback. A Zoom search or capability 401 must not fail a Calendar-indexed run. If Calendar access fails, mark only the Zoom collector failed and allow other collectors to continue. Record and skip individual `get_meeting_assets` 403 and 404 failures. For each qualifying meeting, apply content priority (`meeting_summary` → `my_notes.content_markdown` → transcript items); do not invent a nonexistent `include_zoom_my_notes` flag.

**Gotcha:** `search_meetings` is host-scoped — it silently drops any meeting the authenticated user didn't organize, even ones with real decisions/action items only in My Notes. It's retired from this collector; resolve meetings via Calendar instead (above), never call `search_meetings`. The `include_zoom_my_notes` flag an earlier version of this doc referenced doesn't exist on any current tool — don't pass it.
- **Calendar absence:** Unscheduled calls may not appear in Calendar. A valid Slack call invitation with transcript or summary is real meeting evidence and must not be classified as an absent meeting.
## Occurrence identity and source separation

For each retained Zoom asset, preserve the exact `meeting_uuid` and `meeting_start_time` returned by Zoom. Its source identity is the tuple of the resolved Calendar occurrence identity, `meeting_id`, `meeting_uuid`, and `meeting_start_time`. An exact occurrence match requires both `meeting_id` equal to Calendar `conference.conference_id` and `meeting_start_time` equal to the resolved Calendar `start.dateTime`. Never infer, normalize, or substitute either value.

For a recurring Calendar event, define its resolved series identity as the exact pair of `recurringEventId` and `iCalUID`. If Zoom returns the recurring-series start time instead of the resolved occurrence start, retain the asset only after the exact `meeting_id` match and an explicit returned Zoom series identity that exactly matches that resolved Calendar series identity. If the asset response cannot provide a comparable series identity, reject the fallback. Mark an accepted fallback with `provenance_caveat: recurring-series start_time differs from resolved Calendar occurrence`, the resolved occurrence identity, the resolved series identity, the returned series start timestamp, and the resolved occurrence start timestamp. Report it as a series-start fallback rather than an exact occurrence match. Reject every other time mismatch.

Emit the shared collector report record. Set `terminal_status` independently from coverage. Set `coverage.state` to `non-exhaustive` and include `pagination unavailable` whenever Calendar lists, event lists, or Zoom asset pages cannot page through requested scope. Set `counts.discovered` to resolved Calendar candidates, `counts.read` to candidates for which Calendar and Zoom retrieval completed, `counts.eligible_evidence` to retained Calendar or Zoom evidence records, `counts.known_omitted` to known unresolved candidates or rejected assets, and `counts.out_of_allowlist` to `0`. Do not use a successful exact match for one occurrence to claim coverage of an unread occurrence.

Store Calendar notes and Calendar attachments as separate Calendar evidence, with their own source identity and fingerprint. Do not merge them into Zoom summaries or transcripts. Store Zoom meeting summaries, My Notes, and raw transcripts as separate Zoom evidence records.

## Triage rules

From the result, extract:

- Meeting participants and any contact info surfaced (names, roles, team membership)
- Decisions recorded in the summary or My Notes — anchor each to the project or product it concerns
- Action items from `meeting_summary.next_steps[]` or My Notes — note the meeting topic and `start_time` for cross-reference, and who each item belongs to (My Notes items are often per-person, e.g. "Andrew: ..." vs "Brian: ...")
- Open questions that remain unresolved at the end of the enrichment window

## Extraction rules

- Map participants from `attendees[]` and any speaker lines to people facts.
- Anchor decisions to the project or product they concern.
- For action items, note the meeting topic and date for cross-reference; only the authenticated user's own open items are candidates for filing.
- No local distillation step is needed for a real summary or My Notes doc — both are already distilled. Use directly; only fall back to the raw transcript when neither exists.
