---
name: minutes
description: Search and read meeting transcripts and notes via the minutes CLI
license: MIT
compatibility: macOS (requires minutes CLI)
metadata:
  author: athal7
  version: "1.0"
  provides:
    - meetings
---

Requires: `minutes` CLI installed and configured.

## List recent meetings

```bash
minutes list --limit 20 | jq '.[] | {title, date, duration}'

# Filter to today's meetings
TODAY=$(date +%Y-%m-%d)
minutes list --limit 20 | jq -r ".[] | select(.date | startswith(\"$TODAY\")) | \"MEETING: \(.title) @ \(.date)\""
```

## Get a specific meeting

```bash
# By slug (from list output)
minutes get SLUG | jq '{title, date, duration, transcript}'
```

## Search transcripts

```bash
# Full-text search across all meetings
minutes search "QUERY" | jq '.[] | {title, date, excerpt}'
```

## Action items

```bash
# Open action items across all meetings
minutes actions | jq '.[] | {action, owner, meeting, date}'
```

## Commitments

```bash
# Open commitments (things you said you'd do)
minutes commitments | jq '.[] | {commitment, meeting, date}'
```

## Research a topic

```bash
# Synthesize what meetings say about a topic
minutes research "TOPIC"
```

## Build a person profile

```bash
# Aggregate context about a person across meetings
minutes person "NAME"
```

## Notes

- `minutes list` returns JSON — always pipe through `jq` to extract fields
- Slugs are stable identifiers for meetings; use them with `minutes get`
- `minutes research` and `minutes person` return prose summaries, not JSON
- Use `minutes actions` and `minutes commitments` for follow-up tracking
