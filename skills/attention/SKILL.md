---
name: attention
description: Energy and spoon check — come up for air, see what needs attention without breaking focus
license: MIT
compatibility: opencode
metadata:
  requires:
    - agent
    - calendar
    - reminders
    - issues
    - source-control
---

# Skill: Attention

**Trigger:** "Come up for air", "Attention check", "How's my energy?", "What's on my reminders?"

---

## Step 0: Read the current session (no external tools)

Build `CURRENT` from in-context signals only — do not call any external tools for this step:

- in-progress todo item (if any)
- last 1–2 user messages — what is this session aimed at?
- current branch and dirty files via your `source-control` capability

Summarize as: one-line description + urgency tag (time-sensitive / steady / exploratory / idle).
If nothing is active, `CURRENT = idle`.

`CURRENT` is internal scratch — never print it.

---

## Step 1: Gather context (all in parallel)

- **Sessions:** use your `agent` capability with `sessions-today.sql`, `sessions-summary.sql`, `sessions-concurrent.sql` from this skill directory
- **Calendar:** use your `calendar` capability for today's events and current time, scoped to calendars configured for attention check. Compute `RUNWAY` = minutes until the earlier of (next event, 4pm). 4pm is the wind-down boundary — buffer for gradual transition, not end of work.
- **Reminders:** use your `reminders` capability — overdue, due today, no due date — scoped to lists configured for attention check
- **Work:** use your `source-control` and `issues` capabilities for review requests, received reviews, and assigned work. Prioritize closest-to-done: approved merge request ready to merge → received review to address → incoming review request → new work. Group linked merge requests and issues together. Flag any "In Progress" issue whose merge request has changes requested or a conflict. Consult your `source-control` capability's known gotchas before querying reviews. "Received review to address" means a reviewer left feedback on **your** merge request — never surface another person's merge request under this category. When a surfaced merge request or issue matches `CURRENT` (same branch / linked issue), tag it `[active]` — do not list it again in top-items.

---

## Step 2: Score energy (internally — don't output this)

Score on a single scale using the worst of: user messages today (< 30 = High, 30–80 = Medium, > 80 = Low), peak concurrent sessions (1–2 = High, 3–4 = Medium, 5+ = Low), and `RUNWAY` (≥ 90m = High, 30–90m = Medium, < 30m = Low). Session titles with high topic variety or cross-repo jumps compound switching cost — nudge down one level.

---

## Step 3: Surface the view

One snapshot. If something has been waiting and someone else is affected, mention it once, plainly.

Every output starts with the same signal block:

```
Energy: <Low|Medium|High>
  msgs steered: X   concurrent: X   runway: Xm
```

When comparing items to `CURRENT`: if `CURRENT ≠ idle` and an item is more urgent, mark it `↑ switch`. If less urgent, mark it `↓ later` and only include if there's room. If nothing surfaced is more urgent than `CURRENT`, the recommendation is "continue current."

**LOW**
```
[signal block]

Take care of yourself first. Are you hydrated? Have you eaten?

Top work: [single most urgent item — or "continue current" if nothing more urgent]
Top personal: [single most important personal item]

Everything else can wait.
```

**MEDIUM**
```
[signal block]

[1–2 items — mix of work and personal, compared against CURRENT]
[Flag any stuck/blocked items briefly]

How does your body feel right now?
```

**HIGH**
```
[signal block]

[3–4 items — mix of work and personal, excluding items tagged [active]]

Is there anything nagging that isn't on this list?
What do you want to focus on?
```
