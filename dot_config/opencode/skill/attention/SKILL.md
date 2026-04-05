---
name: attention
description: Come up for air — surface what needs attention now, filtered by energy and spoon budget
---

# Skill: Attention

A calm, low-interruption attention check. Surfaces what matters *right now* without overwhelming — designed for a monotropic brain that needs to transition out of deep focus gently.

**Design principles:**
- Reduce, don't aggregate. Show the minimum useful signal.
- Respect energy. If spoons are low, say so clearly and show less.
- Don't decide for you. Offer options, not directives.
- Silent during work. This skill is for when *you* choose to check in.

---

## Step 1: Read energy level (spoon check)

### WakaTime — coding load today

```bash
wakatime-cli --today 2>/dev/null | head -5
```

This shows hours coded today. Also check the week:

```bash
# Duration this week from WakaTime (last 7 days)
wakatime-cli --range "last 7 days" 2>/dev/null | head -5
```

Interpret:
- **< 2h today** → spoons likely available
- **2–4h today** → moderate load, be selective
- **> 4h today** → significant cognitive use; prompt to rest before more

### Calendar density today

Run the bundled AppleScript to read today's remaining events:

```bash
osascript "$(dirname $0)/calendar-today.applescript"
```

Count events and check for gaps. Dense calendar (3+ remaining events with little gap) = lower available spoons.

### Synthesize spoon level

| WakaTime today | Calendar remaining | Spoon level |
|---------------|-------------------|-------------|
| < 2h | 0–1 events | Full |
| 2–4h | 1–2 events | Moderate |
| > 4h | Any | Low |
| Any | 3+ events | Low |

---

## Step 2: Read Apple Reminders

```bash
osascript "$(dirname $0)/reminders-due.applescript"
```

---

## Step 3: Surface the view

Present a **NOW / NEXT / LATER** view, scaled to spoon level.

### If spoons are LOW

```
--- Attention check ---
Energy: Low (coded Xh today, Y events still ahead)

Take care of yourself first.
- Are you hydrated?
- Have you eaten?
- Is there anything with a hard deadline today?

One thing if needed: [single most urgent item]

Everything else can wait. You've done enough.
```

### If spoons are MODERATE

```
--- Attention check ---
Energy: Moderate

NOW (needs action today):
  • [Overdue reminders, max 2]
  • [Hard-deadline calendar items, max 1]

NEXT (on your radar):
  • [Due-soon reminders, max 2]
  • [Next calendar event with time]

Anything feel off about this list?
```

### If spoons are FULL

```
--- Attention check ---
Energy: Good

NOW:
  • [Overdue + today reminders, max 3]
  • [Any calendar items starting soon]

NEXT:
  • [Due this week, max 3]

LATER (not urgent, just visible):
  • [Anything else you want to name]

What do you want to focus on?
```

---

## Step 4: Items opencode-pilot would have surfaced

If the user asks about work items (Linear issues, GitHub PRs) that were previously surfaced by opencode-pilot, guide them here manually:

```bash
# List your assigned Linear issues
gh issue list --assignee @me --state open --limit 5 2>/dev/null

# Or use Linear skill for richer context
# /linear
```

Only surface work items if spoons are FULL. Otherwise note:
> "Work items are waiting — check in when you have more capacity."

---

## Usage

Load this skill and say:
- "Come up for air" — runs the full attention check
- "How are my spoons?" — just the energy check, no task list
- "What's on my reminders?" — just the reminders step
- "Attention check" — alias for full check

The goal is a gentle, honest picture of where you are — not a to-do list to feel guilty about.
