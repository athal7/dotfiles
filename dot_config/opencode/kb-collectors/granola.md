---
name: granola
enabled: true
priority: 1
authoritative_for: [meetings, decisions, people-contact]
description: Meeting notes, decisions, and people facts from Granola (MCP)
---

## How to query

Use `list_meetings` with `time_range: custom` and `custom_start`/`custom_end` set to the enrichment window. Then call `get_meetings` on any non-trivial meetings. Use `get_meeting_transcript` for verbatim detail when needed. Granola is the authoritative source for meeting content — it covers all history with no date limit.

## Triage

Not all meetings need deep reads. Apply this triage to keep token cost low:

- **Always read:** 1:1s, sig syncs, cycle planning, retrospectives, ad-hoc technical sessions, any meeting with a descriptive title suggesting a decision was made
- **Skim summary only:** standups (read notes, skip transcript), demo days (extract shipped items), all-hands / org-wide meetings (extract only items directly relevant to your work)
- **Skip entirely:** "New note" untitled entries with no participants other than you, HR/benefits/onboarding sessions (privacy), personal/non-work meetings

## What to extract

- People facts: email addresses from participant lists, role/team data, Slack handles if mentioned
- Decisions announced or confirmed in the meeting
- Action items assigned to you or by you
- Project status updates

## What to skip

- Meetings already marked skip in the triage above
- Content already captured from another source (prefer Granola as authoritative, skip the duplicate in Slack)
