---
name: meetings
description: Search and read Minutes meeting notes via MCP — list, search, transcript and notes access
---

Query meeting notes using the Minutes MCP server (`mcp:minutes`). All tools are available as `minutes_*`.

## List recent meetings

```
minutes_list_meetings
```

Returns recent meetings with titles, dates, and slugs.

## Search meetings by keyword

```
minutes_search_meetings query="pricing"
```

Full-text search across all meetings, transcripts, and notes.

## Get a specific meeting

```
minutes_get_meeting slug="2026-03-25-standup"
```

Returns the full meeting markdown — summary, action items, decisions, and transcript.

## Common queries

- **Open action items across all meetings:** `minutes_list_meetings` then check `minutes://actions/open` resource
- **What did someone promise?** `minutes_search_meetings query="Alex pricing"`
- **Meetings about a project:** `minutes_search_meetings query="PROJECT_NAME"`
- **Cross-meeting research:** `minutes_research_topic topic="onboarding"`
- **Person profile:** `minutes_get_person_profile name="Sarah"`

## Resources

| URI | Contents |
|-----|----------|
| `minutes://meetings/recent` | Recent meetings list |
| `minutes://actions/open` | All open action items |
| `minutes://meetings/{slug}` | Specific meeting by slug |

## Tips

- `search_meetings` supports full-text — no need to pull all meetings and filter client-side
- For Slack context around a meeting topic, load the `slack` skill and search alongside Minutes
- Action items have `assignee`, `task`, `due`, and `status` fields in YAML frontmatter
