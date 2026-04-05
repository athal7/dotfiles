---
name: pencil-me-in
description: Family scheduler — find local events and add approved ones to the 105 calendar
---

# Skill: Pencil Me In

Weekly family event digest for Libertyville. Fetch events from local sources, check for conflicts, and add approved events to the 105 calendar.

## Event Sources

These are the default sources. Edit this skill to add or remove feeds.

### ICS Feeds (fetch directly)
- **Libertyville Recreation**: `https://www.libertyville.com/common/modules/iCalendar/iCalendar.aspx?catID=21&feed=calendar`
- **Libertyville Area Moms**: `https://libertyvilleareamoms.com/?post_type=tribe_events&ical=1&eventDisplay=list`

### Pages to scrape
- **Cook Memorial Library**: `https://www.cooklib.org/events-home/`
- **Chicago North Shore Moms**: `https://chicagonorthshoremoms.com/calendar/`

## Calendars

- **105** — target calendar for approved events (already exists in Calendar.app)
- Conflict-check against: Me, Libertyville, Libertyville Area Moms, Library

## Workflow

### Step 1: Fetch events

For ICS feeds, use Python to parse them:

```python
import urllib.request
from icalendar import Calendar
from datetime import date, timedelta

def fetch_ics(url):
    with urllib.request.urlopen(url) as r:
        cal = Calendar.from_ical(r.read())
    today = date.today()
    lookahead = today + timedelta(days=14)
    events = []
    for component in cal.walk():
        if component.name == 'VEVENT':
            dtstart = component.get('DTSTART')
            if dtstart:
                d = dtstart.dt if hasattr(dtstart.dt, 'date') else dtstart.dt
                if isinstance(d, date) and today <= d <= lookahead:
                    events.append({
                        'summary': str(component.get('SUMMARY', '')),
                        'date': d,
                        'location': str(component.get('LOCATION', '')),
                        'url': str(component.get('URL', '')),
                    })
    return events
```

For scraped pages, use `curl` + regex or BeautifulSoup to extract event titles and dates. Focus on events in the next 2 weeks.

### Step 2: Filter to family-relevant events

Prefer:
- Evenings (after 5pm) and weekends
- Family-friendly / kids activities
- Free or low-cost
- Within Libertyville / Lake County

### Step 3: Check for conflicts

Use AppleScript to read existing calendar events for the relevant dates:

```applescript
tell application "Calendar"
  set targetDate to (current date) + (0 * days)
  set endDate to targetDate + (14 * days)
  set conflictCalendars to {"Me", "Libertyville", "Libertyville Area Moms", "Library"}
  set conflicts to {}
  repeat with calName in conflictCalendars
    try
      set cal to calendar calName
      set evts to (every event of cal whose start date >= targetDate and start date <= endDate)
      repeat with evt in evts
        set end of conflicts to {name of evt, start date of evt}
      end repeat
    end try
  end repeat
  return conflicts
end tell
```

### Step 4: Present digest

Show a numbered list of candidate events:

```
Upcoming events (next 2 weeks):

1. Summer Reading Kickoff — Sat Jun 7 10:00am @ Cook Library
   https://www.cooklib.org/event/...

2. Family Movie Night — Fri Jun 6 7:00pm @ Libertyville Recreation
   No conflicts

3. LAM Playdate — Sun Jun 8 2:00pm @ Independence Grove
   ⚠ Conflict: Family picnic (Me calendar)

Add to 105 calendar? Enter numbers separated by commas, or 'none':
```

### Step 5: Add approved events to 105 calendar

For each approved event, add via AppleScript:

```applescript
tell application "Calendar"
  set cal105 to calendar "105"
  set newEvent to make new event at end of events of cal105
  set summary of newEvent to "EVENT TITLE"
  set start date of newEvent to date "Saturday, June 7, 2025 10:00:00 AM"
  set end date of newEvent to date "Saturday, June 7, 2025 11:00:00 AM"
  set url of newEvent to "https://..."
end tell
```

## Add-to-calendar links (email format)

When generating an email digest, format each event as a `data:text/calendar` link or link to a `.ics` file so the recipient can tap to add. Example single-event ICS:

```
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
DTSTART:20250607T100000
DTEND:20250607T110000
SUMMARY:Summer Reading Kickoff
LOCATION:Cook Memorial Library
URL:https://...
END:VEVENT
END:VCALENDAR
```

## Running manually

This skill is invoked on-demand. To run a weekly digest, load this skill and ask:
> "Run pencil me in for this week"

Or to add specific sources:
> "Run pencil me in, also check [URL]"
