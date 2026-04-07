---
name: meetings
description: Search and read Minutes meeting notes via CLI — list, search, transcript and notes access
license: MIT
metadata:
  author: athal7
  version: "1.0"
---

Query meeting notes using the `minutes` CLI.

## List recent meetings

```bash
minutes list
```

## Search meetings by keyword

```bash
minutes search "pricing"
```

Full-text search across all meetings, transcripts, and notes.

## Get a specific meeting

```bash
minutes get 2026-03-25-standup
```

Returns the full meeting markdown — summary, action items, decisions, and transcript.

## Common queries

```bash
minutes actions                # open action items across all meetings
minutes research "onboarding"  # cross-meeting topic research
minutes person "Sarah"         # first-pass profile for a person
minutes consistency            # flag conflicting decisions / stale commitments
```

## Tips

- `minutes search` supports full-text — no need to list all meetings and filter
- For Slack context around a meeting topic, load the `slack` skill and search alongside Minutes
- `minutes research` synthesizes across meetings, decisions, and open follow-ups
