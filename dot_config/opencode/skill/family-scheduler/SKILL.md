---
name: family-scheduler
description: Find local family events and add approved ones to the 105 calendar
---

# Skill: Family Scheduler

Weekly event digest for Libertyville. Fetch events from local sources, check for conflicts, and add approved events to the 105 calendar.

## Event Sources

Edit this skill to add or remove feeds.

### ICS Feeds
- **Libertyville Recreation**: `https://www.libertyville.com/common/modules/iCalendar/iCalendar.aspx?catID=21&feed=calendar`
- **Libertyville Area Moms**: `https://libertyvilleareamoms.com/?post_type=tribe_events&ical=1&eventDisplay=list`

### Pages to scrape
- **Cook Memorial Library**: `https://www.cooklib.org/events-home/`
- **Chicago North Shore Moms**: `https://chicagonorthshoremoms.com/calendar/`

## Calendars

- **105** — target calendar for approved events
- Conflict-check against: Me, Libertyville, Libertyville Area Moms, Library

## Workflow

### Step 1: Fetch events

Run the bundled script to fetch and parse ICS feeds:

```bash
python3 "$(dirname $0)/fetch-events.py"
```

For scraped pages, use `curl` and extract event titles and dates. Focus on events in the next 2 weeks, preferring evenings and weekends, family-friendly, free or low-cost, within Libertyville / Lake County.

### Step 2: Show what's already on the calendar

```bash
osascript "$(dirname $0)/calendar-next-two-weeks.applescript"
```

Show this alongside the fetched events so you can see what's happening those days and decide what fits.

### Step 3: Present digest

Show a numbered list of candidate events alongside any same-day calendar entries, then ask which to add to 105.

### Step 4: Add approved events

```bash
osascript "$(dirname $0)/add-event.applescript" "TITLE" "YYYY-MM-DD HH:MM" "YYYY-MM-DD HH:MM" "URL"
```
