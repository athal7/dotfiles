# Zoom

1. Index Google Calendar events over the UTC enrichment window with `list_events`, then call `get_event` for each event to resolve `conference.conference_id`. Resolve and pass the user's IANA timezone.
2. Dedupe recurring events by both `iCalUID` and conference ID.
3. Call `get_meeting_assets` only for indexed events with a `conference.conference_id`. Do not call Zoom search, `search_describe_capabilities`, or `search_meetings`.
4. Read assets in priority order: `meeting_summary` → `my_notes.content_markdown` → transcript items, last resort.
5. Extract participants, decisions, `next_steps[]` action items, and open questions. Cite meeting topic and date.
