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

Use the same multidimensional framework as the `attention` skill — WakaTime is a proxy, not a direct reading. If `attention` has already run this session, reuse that assessment.

```bash
wakatime-cli --today 2>/dev/null
```

Apply the same table from the attention skill (< 1h = likely available, 1–3h = moderate, 3–5h = caution, > 5h = low). Also factor in time of day and whether there are upcoming calendar events.

| Spoons | What to do |
|--------|-----------|
| Low | Stop here. Planning outings takes energy you don't have right now. |
| Moderate | At most 1 suggestion — low-effort, close by, no prep needed |
| Full | Up to 3 suggestions across open gaps |

### Step 2: Find open gaps in the next two weeks

```bash
# Note: osascript calendar access hangs from the OpenCode server process (TCC issue).
# This is a known limitation — fix is tracked in Work reminders.
# If it hangs after ~5s, kill it and skip gap filtering; present events without calendar gating.
timeout 5 osascript ~/.config/opencode/skill/family-scheduler/calendar-gaps.applescript 2>/dev/null \
  || echo "CALENDAR_UNAVAILABLE"
```

If `CALENDAR_UNAVAILABLE`: skip gap filtering, focus on weekend days in the next two weeks as default assumption, and note that calendar wasn't available.

### Step 3: Fetch candidate events

```bash
python3 ~/.config/opencode/skill/family-scheduler/fetch-events.py
```

**Known issues:**
- `icalendar` package required — install with `pip install icalendar` if missing
- Libertyville Area Moms ICS returns HTTP 403 — blocked, skip silently
- For scraped pages (Cook Library, Chicago North Shore Moms), use `curl` + WebFetch

Filter candidates to those falling within open gaps from Step 2. If calendar unavailable, include all weekend events.

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
osascript "~/.config/opencode/skill/family-scheduler/add-event.applescript" "TITLE" "YYYY-MM-DD HH:MM" "YYYY-MM-DD HH:MM" "URL"
```
