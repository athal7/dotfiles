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

## Step 1: Discover which calendars and reminder lists to scope to

Before querying the calendar or reminders, find the entries flagged for attention check in the user's machine-local config. The system maintains per-machine settings that mark a subset of calendars and reminder lists as in-scope; everything else is deliberately out of scope.

Look for entries shaped like `attention_check: true` under calendar and reminder list definitions, and collect their display names.

If no entries are flagged, ask the user which calendars and lists to use — do not default to all of them. Using all surfaces noise (family members' calendars, subscriptions, holiday feeds, shared lists) that breaks the focus signal.

The collected names are the only calendars and lists the next step should query.

## Step 2: Gather context (all in parallel)

- **Sessions:** use your `agent` capability with `sessions-today.sql`, `sessions-summary.sql`, `sessions-concurrent.sql` from this skill directory
- **Calendar:** use your `calendar` capability for today's events and current time, **filtered to the calendar names from Step 1 only**. **Exclude events the user has declined** — for any event with attendee participation status available, drop it if the user's status is "declined." A declined event no longer holds time on the calendar and must not count toward `RUNWAY`. Compute `RUNWAY` = minutes until the earlier of (next non-declined event on those calendars, 4pm). 4pm is the wind-down boundary — buffer for gradual transition, not end of work.
- **Reminders:** use your `reminders` capability **filtered to the list names from Step 1 only** and **only fetch open (incomplete) reminders** — completed items are done and must never appear in the attention view. Reminder counts climb over time; querying without the open filter surfaces a stale archive that masks what's actually in flight.

  Bucket the open reminders by urgency:
  1. **Overdue** — due before today. Always surface; these are the first thing the user should see.
  2. **Due today** — due date is today. Surface if any exist.
  3. **No due date with explicit priority** — undated reminders the user has tagged `high`, `medium`, or `low`. The user has triaged these; treat as standing items the focus check should respect, sorted by priority.
  4. **No due date, priority `none`** — awaiting triage. The user has not decided whether these matter. Sample at most 3, oldest-created first. When surfaced, the expected response is "prioritize or act" — tag with a priority, complete, or delete; do not treat as a task to do as-is.

  Future-dated reminders (tomorrow onward) are out of scope for the attention check — they belong to a planning ritual, not a focus check.

  Within each bucket, sort by priority (`high` → `medium` → `low` → `none`), then by due date / creation date.
- **Work:** use your `source-control` and `issues` capabilities for review requests, received reviews, and assigned work. Prioritize closest-to-done: approved merge request ready to merge → received review to address → incoming review request → new work. Group linked merge requests and issues together. Flag any "In Progress" issue whose merge request has changes requested or a conflict. Consult your `source-control` capability's known gotchas before querying reviews. "Received review to address" means a reviewer left feedback on **your** merge request — never surface another person's merge request under this category. When a surfaced merge request or issue matches `CURRENT` (same branch / linked issue), tag it `[active]` — do not list it again in top-items. Items in the same repository as the current working directory rank higher than items in other repositories at the same priority level.

---

## Step 3: Score energy (internally — don't output this)

Score on a single scale using the worst of: user messages today (< 30 = High, 30–80 = Medium, > 80 = Low), peak concurrent sessions (1–2 = High, 3–4 = Medium, 5+ = Low), and `RUNWAY` (≥ 90m = High, 30–90m = Medium, < 30m = Low). Session titles with high topic variety or cross-repo jumps compound switching cost — nudge down one level.

---

## Step 4: Surface the view

One snapshot. If something has been waiting and someone else is affected, mention it once, plainly.

Every output starts with the same signal block:

```
Energy: <Low|Medium|High>
  msgs steered: X   concurrent: X   runway: Xm
```

When comparing items to `CURRENT`: if `CURRENT ≠ idle` and an item is more urgent, mark it `↑ switch`. If less urgent, mark it `↓ later` and only include if there's room. If nothing surfaced is more urgent than `CURRENT`, the recommendation is "continue current." Items in the same repository as the current working directory are considered one urgency level higher than equivalent items in other repositories.

When choosing the personal item(s) to surface, use the reminder buckets in order: overdue → due today → undated-with-priority → undated-none. Within a bucket, prefer the highest-priority item.

Items from bucket 4 (priority `none`) are surfaced with an inline `[triage]` tag — these are unprioritized, so the expected response is to set a priority, act, or delete, not to treat them as a task. Energy gating for bucket 4:

- **LOW** — suppress bucket 4 entirely. No spoons for triage.
- **MEDIUM** — prefer buckets 1–3. If buckets 1–3 are empty, always surface one bucket-4 item tagged `[triage]`.
- **HIGH** — include up to 3 bucket-4 items tagged `[triage]` when room permits, even when buckets 1–3 also have content.

**LOW**
```
[signal block]

Take care of yourself first. Are you hydrated? Have you eaten?

Top work: [single most urgent item — or "continue current" if nothing more urgent]
Top personal: [overdue reminder if any, else due-today, else highest-priority undated-with-priority — bucket 4 suppressed at LOW]

Everything else can wait.
```

**MEDIUM**
```
[signal block]

[1–2 items — mix of work and personal, compared against CURRENT; personal items pulled from buckets 1–3, falling back to one bucket-4 `[triage]` item when 1–3 are empty]
[Flag any stuck/blocked items briefly]

How does your body feel right now?
```

**HIGH**
```
[signal block]

[3–4 items — mix of work and personal, excluding items tagged [active]; personal items pulled from buckets 1–3 first, then up to 3 bucket-4 `[triage]` items when room permits]

Is there anything nagging that isn't on this list?
What do you want to focus on?
```
