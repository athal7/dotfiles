---
name: ical
description: Read and write macOS Calendar events via the native EventKit CLI
license: MIT
compatibility: macOS (requires ical CLI)
metadata:
  author: athal7
  version: "1.0"
  provides:
    - calendar
---

Native macOS Calendar CLI built on EventKit. Always use `-o json` for agent use.

## Today's events

```bash
ical today -o json
```

## List events in a date range

```bash
# Natural language or ISO 8601 dates
ical list -o json -f "monday" -t "friday"
ical list -o json -f "2026-04-14" -t "2026-04-21"

# Filter by calendar, limit results
ical list -o json -c "Work" -n 20
```

## Upcoming events

```bash
# Next N days (default: 7)
ical upcoming -o json
ical upcoming -o json --days 14
```

## Search events

```bash
# Searches title, location, notes; defaults to ±30 days from today
ical search "standup" -o json
ical search "dentist" -o json -f "2026-01-01" -t "2026-12-31"
```

## Show event details

```bash
# By full or partial event ID
ical show --id "D888D384-2035-47FE-A4B1-0C6B64355420:abc123" -o json
```

## Add an event

```bash
ical add "Team standup" \
  -s "2026-04-14 10:00" \
  -e "2026-04-14 10:30" \
  -c "Work" \
  --timezone "America/Chicago" \
  -l "Zoom" \
  -n "Weekly sync" \
  -o json

# All-day event
ical add "Conference" -s "2026-05-01" --all-day -c "Work" -o json

# Recurring event
ical add "Weekly review" -s "2026-04-14 09:00" -r weekly \
  --repeat-days "mon" --repeat-until "2026-12-31" -o json
```

## Update an event

```bash
# Pass full or partial event ID
ical update "D888D384-2035-47FE-A4B1-0C6B64355420:abc123" \
  -T "New title" \
  -s "2026-04-14 11:00" \
  -e "2026-04-14 11:30" \
  -o json

# For recurring events: update only this occurrence or this + future
ical update EVENT_ID --span this -T "One-off title" -o json
ical update EVENT_ID --span future -s "2026-04-14 10:00" -o json
```

## Delete an event

```bash
# --force skips confirmation prompt (required for non-interactive use)
ical delete --id "FULL_EVENT_ID" --force -o json

# Recurring: delete this occurrence only, or this + all future
ical delete --id "FULL_EVENT_ID" --force --span this
ical delete --id "FULL_EVENT_ID" --force --span future
```

## List calendars

```bash
ical calendars -o json
```

## JSON output format

Key fields in event JSON:

| Field | Description |
|---|---|
| `id` | Full event ID — use for update/delete/show |
| `title` | Event title |
| `start_date` / `end_date` | ISO 8601, UTC |
| `all_day` | Boolean |
| `calendar` | Calendar name |
| `calendar_id` | Calendar UUID |
| `recurring` | Boolean |
| `timezone` | IANA timezone string |
| `location` | Location string |
| `notes` | Notes/description |

## Notes

- Always use `--force` when deleting non-interactively — omitting it will block waiting for input
- Event IDs are stable; use `--id` for exact lookup to avoid prefix ambiguity
- Dates accept natural language (`today`, `next monday`, `in 2 weeks`) or ISO 8601
- Writes require Calendar access permissions — granted at first use via macOS TCC dialog
