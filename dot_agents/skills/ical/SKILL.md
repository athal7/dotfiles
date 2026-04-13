---
name: ical
description: iCal CLI for managing calendar events via EventKit — reads and writes macOS Calendar
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - calendar
---

# Skill: ical

Native macOS Calendar CLI (`ical`). Full CRUD for events, natural language dates, JSON output.

## Key gotcha: timestamps are UTC

All `start_date` and `end_date` values in JSON output are UTC (suffix `Z`). **Always convert to local time before displaying.** Do not slice the string directly — you will show the wrong time.

```bash
# List today's events as JSON
ical today -o json

# Date range
ical list -o json --from "2026-04-13" --to "2026-04-14"
```

To convert in shell:
```bash
ical today -o json | jq -r '.[] | .start_date | sub("Z$"; "+00:00") | fromdateiso8601 | strflocaltime("%H:%M")'
```

Or in Python:
```python
from datetime import datetime
dt = datetime.fromisoformat(start_date.replace("Z", "+00:00")).astimezone()
time_str = dt.strftime("%H:%M")
```

## Common commands

```bash
# Today's agenda
ical today -o json

# Filter by calendar
ical today -o json -c "Work"

# Upcoming N days
ical upcoming -o json

# Add event
ical add "Team sync" --calendar "Work" --start "tomorrow 10am" --end "tomorrow 11am"

# List calendars
ical calendars -o json
```

## all_day events

When `all_day` is `true`, the time component is meaningless — display as `all-day`, not a converted timestamp.
