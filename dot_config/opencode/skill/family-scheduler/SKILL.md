---
name: family-scheduler
description: Find local family events that fit open calendar gaps, respecting current energy
---

# Skill: Family Scheduler

Finds local events that fit into actual gaps in the next two weeks — not a firehose, but a small set of suggestions matched to available time and energy.

**Design principles:**
- Only suggest events for days/times that are genuinely open
- Respect spoon level — if energy is low, suggest at most one easy thing
- Fewer, better suggestions over a complete list

## Event Sources

Edit this skill to add or remove feeds.

### ICS Feeds
- **Libertyville Recreation**: `https://www.libertyville.com/common/modules/iCalendar/iCalendar.aspx?catID=21&feed=calendar`
- **Libertyville Area Moms**: `https://libertyvilleareamoms.com/?post_type=tribe_events&ical=1&eventDisplay=list`

### Pages to scrape
- **Cook Memorial Library**: `https://www.cooklib.org/events-home/`
- **Chicago North Shore Moms**: `https://chicagonorthshoremoms.com/calendar/`

## Target calendar

**105** — add approved events here.

---

## Workflow

### Step 1: Check spoon level

Run the WakaTime check from the attention skill:

```bash
wakatime-cli --today 2>/dev/null | head -5
```

| Spoons | What to do |
|--------|-----------|
| Low | Stop here. Not a good time to plan outings. |
| Moderate | Find at most 1 suggestion — something low-effort, close by, no prep needed |
| Full | Find up to 3 suggestions across open gaps |

### Step 2: Find open gaps in the next two weeks

```bash
osascript "$(dirname $0)/calendar-gaps.applescript"
```

This returns weekend and evening slots that have no existing events — these are the only windows to consider for suggestions.

### Step 3: Fetch candidate events

```bash
python3 "$(dirname $0)/fetch-events.py"
```

For scraped pages, use `curl`. Then filter candidates to only those that fall within the gaps identified in Step 2. Discard anything on a busy day.

### Step 4: Present suggestions

Show only events that fit open gaps. Keep it short:

```
A couple of things that fit your open time:

1. Summer Reading Kickoff — Sat Jun 7 10am @ Cook Library (free, ~1h)
   cooklib.org/...

2. Family Movie Night — Fri Jun 13 7pm @ Libertyville Rec (free)
   libertyville.com/...

Add either to 105? (1, 2, both, or skip)
```

If spoons are moderate: show only 1, frame it gently ("One thing if you want it").
If nothing fits open gaps: say so briefly and stop.

### Step 5: Add approved events

```bash
osascript "$(dirname $0)/add-event.applescript" "TITLE" "YYYY-MM-DD HH:MM" "YYYY-MM-DD HH:MM" "URL"
```
