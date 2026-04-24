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

## Step 1: Gather context (all in parallel)

- **Sessions:** use your `agent` capability with `sessions-today.sql`, `sessions-summary.sql`, `sessions-concurrent.sql` from this skill directory
- **Calendar:** use your `calendar` capability for today's events and current time, then compute `RUNWAY` = minutes until the earlier of (next event, 4pm). 4pm is the wind-down boundary — buffer for gradual transition out of focus, not end of work (monotropic transitions need runway).
- **Reminders:** use your `reminders` capability — overdue, due today, no due date
- **Work:** use your `source-control` and `issues` capabilities for review requests, received reviews, and assigned work. Prioritize closest-to-done: approved merge request ready to merge → received review to address → incoming review request → new work. Group linked merge requests and issues together. Flag any "In Progress" issue whose merge request has changes requested or a conflict.

---

## Step 2: Score energy (internally — don't output this)

Score on a single scale combining message load, concurrency, and runway. Use the worst of the three.

| Signal | High | Medium | Low |
|---|---|---|---|
| User messages today | < 30 | 30–80 | > 80 |
| Peak concurrent sessions | 1–2 | 3–4 | 5+ |
| `RUNWAY` (minutes) | ≥ 90 | 30–90 | < 30 |

Session titles with high topic variety or cross-repo jumps compound switching cost — nudge down one level.

---

## Step 3: Surface the view

One snapshot. If something has been waiting and someone else is affected, mention it once, plainly.

Every output starts with the same signal block so the score is legible:

```
Energy: <Low|Medium|High>
  msgs steered: X   concurrent: X   runway: Xm
```

**LOW**
```
[signal block]

Take care of yourself first. Are you hydrated? Have you eaten?

Top work: [single most urgent item — no action unless truly time-sensitive]
Top personal: [single most important personal item]

Everything else can wait.
```

**MEDIUM**
```
[signal block]

[1–2 quick wins — mix of work and personal]
[Flag any stuck/blocked items briefly]

How does your body feel right now?
```

**HIGH**
```
[signal block]

[3–4 items — mix of work and personal]

Is there anything nagging that isn't on this list?
What do you want to focus on?
```
