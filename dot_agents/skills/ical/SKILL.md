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

Run `ical --help` and `ical <command> --help` to discover commands. This skill only documents silent failure modes that help text won't surface.

## Timestamps are UTC — always convert before displaying

All `start_date` and `end_date` values in JSON output are UTC (suffix `Z`). Slicing the string directly will show the wrong time. Convert to local time:

```bash
# Shell
ical today -o json | jq -r '.[] | .start_date | sub("Z$"; "+00:00") | fromdateiso8601 | strflocaltime("%H:%M")'

# Python
from datetime import datetime
dt = datetime.fromisoformat(start_date.replace("Z", "+00:00")).astimezone()
time_str = dt.strftime("%H:%M")
```

When `all_day` is `true`, skip conversion entirely — display as `all-day`.
