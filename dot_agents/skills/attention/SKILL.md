---
name: attention
description: Energy and spoon check — come up for air, see what needs attention without breaking focus
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  requires:
    - agent
    - calendar
    - reminders
    - meetings
    - chat

    - issues
---

# Skill: Attention

**Check-in (on demand):** When you choose to come up for air, this skill surfaces a spoon-aware NOW/NEXT/LATER view.

**Calendar access:** use your `calendar` capability — fast native EventKit CLI, supports reads and writes.

---

## Step 1: Gather context

Run all of these before forming any view:

- Use your `agent` capability to fetch today's OpenCode sessions. Retrieve per-session breakdown (user messages = active engagement, duration) and summary totals including peak concurrent sessions. Filter out subagent noise (worktree paths + "@... subagent" titles). The SQL files `sessions-today.sql`, `sessions-summary.sql`, and `sessions-concurrent.sql` in the skill directory can be passed to the capability. Strip `$CODE_DIR/` prefix from the `repo` column for readability.

- Use your `calendar` capability to get today's events across all configured calendars. Also output the current day of week and time.

- Use your `reminders` capability to fetch:
  - Overdue items
  - Items due today (incomplete only)
  - Items with no due date (all priorities, incomplete) — note: use the `all` scope, not `upcoming`, since `upcoming` only returns future-dated items

- Use your `meetings` capability to list today's processed meetings (for social/emotional load inference). Filter to items whose date starts with today's date, limit 20.

- Use your `chat` capability to find recent Slack mentions waiting on you in the last 8 hours. Search for mentions of your user ID in the last 8h.

- Note: priority strings for your `reminders` capability are `"high"`, `"medium"`, `"low"`, `"none"` — not integers.

---

## Step 2: Assess the situation holistically

Before surfacing anything, reason across all inputs together **internally**. Do not output the intermediate spoon accounting or reasoning steps — only output the final check in Step 3.

**Core principle: protect capacity first, output second.**
The goal is sustainable contribution. Reducing overwhelm matters more than surfacing every pending item.

---

**Spoon accounting (Dr. Megan Anna Neff's framework):**

Spoons aren't just quantity — they're multidimensional. Autistic/AuDHD energy depletion happens across multiple axes:

- **Cognitive load** — deep focus, problem-solving, context switching
- **Social/masking load** — meetings, communication, being "on"
- **Sensory load** — environment, noise, stimulation throughout the day
- **Emotional/interoceptive load** — accumulated stress that may not have registered consciously

**What drains most:** The two biggest cognitive load signals from sessions are:
1. **User message count** — each message you sent required you to engage, evaluate, redirect, or decide. High counts mean you were actively steering work, not just delegating.
2. **Concurrent sessions** — running multiple sessions at once fragments attention even if each one felt short. Peak concurrent > 2 is meaningful switching cost.

Session duration alone is a weak signal — a long autonomous session burns few spoons; a short highly-interactive one burns many.

**Reading session data:**
- Scan session titles for topic variety — many different subjects = high context-switch load
- Cross-repo jumps (dotfiles → app → dotfiles) compound the switching cost
- Check earliest session start — a long elapsed day is tiring even at low intensity

**Interoceptive caveat:** With alexithymia, the body often doesn't signal depletion until it's too late. These metrics are proxies. Treat high output as a *warning* signal, not a green light — boom-and-bust cycles start by overdoing it on good days.

**Spoon table — use the worse of the two signals:**

| User messages today | Spoon signal |
|---------------------|--------------|
| < 30 | Likely available |
| 30–80 | Moderate |
| 80–150 | Caution |
| > 150 | Low |

| Peak concurrent sessions | Modifier |
|--------------------------|----------|
| 1–2 | No change |
| 3–4 | +1 level toward Low |
| 5+ | +2 levels toward Low (cap at Low) |

The table is a starting point, not a formula. Use contextual judgment — a day heavy on meetings should shift the estimate lower independent of session counts. A low message count with many meetings can still be depleting.

**Time and pacing:**
- `GAP` = minutes until next event (or rest of day free)
- `END_OF_DAY` = minutes until 6pm
- GAP < 30m → don't recommend starting a tunnel; suggest quick wins or rest
- Past 6pm → wind-down mode regardless of session count
- Full spoons + GAP < 30m → treat as Moderate

**Reminder weighting:**
- All reminders are inputs — filter before surfacing. Ask: does this need attention *right now*, given spoons, time, and energy type?
- One well-chosen thing beats five that create paralysis
- Balance work and personal — a day of only work tasks is a signal, not a success
- Considerateness without self-sacrifice: if something has been waiting and someone else is depending on it, mention it once, plainly, as information — not guilt

**Monotropism / attentional tunnel awareness:**
- Entering a new tunnel has a real cost — only recommend it if GAP is large enough and spoons support it
- Prefer finishing or resting over starting something new when in doubt
- Suggest task types that match the current cognitive mode

**Alexithymia prompts** — always include at least one body/state check, phrased as genuine care:
- "Are you hydrated? Have you eaten?"
- "How does your body feel right now — not your to-do list, your body?"
- "Is there anything you've been ignoring that your nervous system might be tracking?"
- Never frame as productivity checks

---

## Step 3: Surface the view

One coherent snapshot — not a stack of sections. Tune depth and length to spoon level.

### If spoons are LOW (or past 6pm)

---
**Attention check**
Energy: Low (X msgs, Xm until [next event / end of day])

Take care of yourself first.
- Are you hydrated? Have you eaten?
- Is there anything with a hard deadline today?

[One actionable thing if truly needed, otherwise nothing]

Everything else can wait.

---

### If spoons are MODERATE (or GAP < 30m)

---
**Attention check**
Energy: Moderate — Xm before [next event / 6pm]

[2–3 items that make sense given time and energy — mix of urgent and lightweight]
[Note any blocked/stuck items briefly]

How does your body feel right now?

---

### If spoons are FULL and GAP ≥ 30m

---
**Attention check**
Energy: Good — Xm before [next event / 6pm]

[1–2 things worth doing now — chosen for fit, not for urgency alone]
[If something has been waiting and someone else is affected, mention it once, plainly]
[One personal item if only work is surfacing]

Is there anything nagging that isn't on this list?
What do you want to focus on?

---

## Step 4: Work items (skip only when LOW)

If spoons are LOW, skip this step entirely. Don't mention the backlog — it can wait.

When spoons are MODERATE or better, surface work items. Tune the depth to the energy level: at MODERATE, show 1–2 items max and prefer quick wins; at FULL, show up to 3–4 and include longer-horizon items worth starting. Don't list everything — pick the most worth attention given the available gap, and surface them as part of the unified picture in Step 3 — not as a separate dump. Flag a long-waiting or high-impact item if it genuinely deserves a mention, once, without guilt-framing.

### Pull requests — four categories to check

Use `gh` to fetch:

1. Review requested from you
2. Your PRs with changes requested
3. Your PRs with merge conflicts (`mergeStateStatus == "DIRTY"`)
4. Your PRs awaiting review (no decision yet, not draft)

### Issues — by state

Use your `issues` capability to fetch issues assigned to you, grouped by state (in progress, unstarted, backlog).

### Cross-reference PRs ↔ issues

After fetching both:

- If an issue has a linked PR that also appears in the PR categories above, **group them together** — don't show the same work twice
- Flag if an issue is "In Progress" but its PR has `CHANGES_REQUESTED` or `DIRTY` — that's a stuck item
- Flag if a PR is ready for review but has no linked issue — may be untracked work

Present as a unified list, grouped by work item (not by tool), with the most actionable status shown.

### Starting work from here

When you decide to act on a work item, use your `agent` capability to dispatch a session. **Do not use `opencode run` or any CLI directly** — go through the capability's API so that:

- PR reviews always get a worktree sandbox (isolated branch, no risk of clobbering the live repo)
- Sessions are reused when idle rather than spawned fresh every time
- The dispatch is visible in OpenCode Desktop / web UI

The `agent` capability's dispatch instructions specify exactly how to create worktrees and route sessions.

---

## Usage

Load this skill and say:
- "Come up for air" — runs the full attention check
- "How are my spoons?" — just the energy check, no task list
- "What's on my reminders?" — just the reminders step
- "Attention check" — alias for full check

The goal is a gentle, honest picture of where you are — not a to-do list to feel guilty about.
