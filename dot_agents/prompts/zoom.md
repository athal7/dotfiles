# Zoom

1. `search_meetings` over the window — requires `from` and `to` as UTC ISO-8601, and a `timezone` you must get from context or ask for. Keep meetings where `has_summary` or `has_transcript` is true.
2. `get_meeting_assets` per qualifying meeting, with `meetingId = meeting_uuid`.
3. Read in priority order: `summary_markdown` (already distilled by Zoom AI Companion) → `my_notes.content_markdown` → transcript items, last resort, stitched by `start` time.

Extract decisions, action items from `next_steps[]`, participants and roles, open questions. Cite meeting topic and date.
