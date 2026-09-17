# Zoom

1. Enumerate every accessible Google Calendar with `list_calendars`, index each calendar over the UTC enrichment window with `list_events`, then call `get_event` for every candidate to resolve occurrence/start identity and `conference.conference_id`. Resolve and pass the user's IANA timezone.
2. Dedupe only duplicate-calendar mirrors of the same resolved occurrence: require matching `iCalUID`, occurrence/start identity, and conference ID. Retain distinct occurrences in the same series even when iCalUID or conference ID match.
3. Call `get_meeting_assets` only for resolved events with a `conference.conference_id`; retain an asset only when its `meeting_id` equals the conference ID and its `start_time` equals the resolved event start. Do not call Zoom search, `search_describe_capabilities`, or `search_meetings`, and do not add a search or capability fallback.
4. Read assets in priority order: `meeting_summary` → `my_notes.content_markdown` → transcript items, last resort.
5. Extract participants, decisions, `next_steps[]` action items, and open questions. Cite meeting topic and date.
