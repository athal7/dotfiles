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
    - code-review
    - branching
---

# Skill: Attention

**Check-in (on demand):** When you choose to come up for air, this skill surfaces an energy-aware view of what matters most right now.

**Calendar access:** use your `calendar` capability — fast native EventKit CLI, supports reads and writes.

---

## Step 1: Gather context

Run all of these before forming any view:

- Use your `agent` capability to fetch today's OpenCode sessions. Retrieve per-session breakdown (user messages = active engagement, duration) and summary totals including peak concurrent sessions. Filter out subagent noise (worktree paths + "@... subagent" titles). The SQL files `sessions-today.sql`, `sessions-summary.sql`, and `sessions-concurrent.sql` in the skill directory can be passed to the capability. Strip `$CODE_DIR/` prefix from the `repo` column for readability.

- Use your `calendar` capability to get today's events. Query **only the calendars configured in chezmoi data** — run `chezmoi data` and read all keys under `.calendars` to get the list of calendar names. Run a separate query per calendar name and combine the results. Do not pull from other calendars. Also output the current day of week and time.

- Use your `reminders` capability to fetch:
  - Overdue items
  - Items due today (incomplete only)
  - Items with no due date (all priorities, incomplete) — note: use the `all` scope, not `upcoming`, since `upcoming` only returns future-dated items

- Use your `meetings` capability to list today's processed meetings (for social/emotional load inference). Filter to items whose date starts with today's date, limit 20.

- Use your `chat` capability to find recent mentions waiting on you in the last 8 hours. Search for mentions of your user ID in the last 8h.

- Note: priority strings for your `reminders` capability are `"high"`, `"medium"`, `"low"`, `"none"` — not integers.

---

## Step 2: Assess the situation holistically

Before surfacing anything, reason across all inputs together **internally**. Do not output the intermediate energy accounting or reasoning steps — only output the final check in Step 3.

**Core principle: protect capacity first, output second.**
The goal is sustainable contribution. Reducing overwhelm matters more than surfacing every pending item.

---

**Energy accounting:**

Energy isn't just quantity — it's multidimensional. Depletion happens across multiple axes:

- **Cognitive load** — deep focus, problem-solving, context switching
- **Social load** — meetings, communication, being "on"
- **Sensory load** — environment, noise, stimulation throughout the day
- **Emotional load** — accumulated stress that may not have registered consciously

**What drains most:** The two biggest cognitive load signals from sessions are:
1. **User message count** — each message sent required active engagement, evaluation, and decisions. High counts mean actively steering work, not just delegating.
2. **Concurrent sessions** — running multiple sessions at once fragments attention even if each one felt short. Peak concurrent > 2 is meaningful switching cost.

Session duration alone is a weak signal — a long autonomous session is low load; a short highly-interactive one is high load.

**Reading session data:**
- Scan session titles for topic variety — many different subjects = high context-switch load
- Cross-repo jumps (dotfiles → app → dotfiles) compound the switching cost
- Check earliest session start — a long elapsed day is tiring even at low intensity

**Important caveat:** These metrics are proxies for energy state, not a direct readout. Treat high output as a *warning* signal, not a green light — the body doesn't always signal depletion until it's too late.

**Energy table — use the worse of the two signals:**

| User messages today | Energy signal |
|---------------------|---------------|
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
- GAP < 30m → don't recommend starting a deep-focus task; suggest quick wins or rest
- Past 6pm → wind-down mode regardless of session count
- Full energy + GAP < 30m → treat as Moderate

**Reminder weighting:**
- All reminders are inputs — filter before surfacing. Ask: does this need attention *right now*, given energy, time, and cognitive mode?
- One well-chosen thing beats five that create paralysis
- Balance work and personal — a day of only work tasks is a signal, not a success
- Considerateness without self-sacrifice: if something has been waiting and someone else is depending on it, mention it once, plainly, as information — not guilt

**Attentional focus awareness:**
- Entering a new deep-focus task has a real cost — only recommend it if GAP is large enough and energy supports it
- Prefer finishing or resting over starting something new when in doubt
- Suggest task types that match the current cognitive mode

**Self-care check** — always include at least one body/state check, phrased as genuine care:
- "Are you hydrated? Have you eaten?"
- "How does your body feel right now — not your to-do list, your body?"
- "Is there anything you've been putting off that's been nagging at you?"
- Never frame as productivity checks

---

## Step 3: Surface the view

One coherent snapshot — not a stack of sections. Tune depth and length to energy level.

**Always surface the top 1 work priority and top 1 personal/reminder priority** regardless of energy level — even when LOW. The goal is never to hide what matters most, just to limit how much is presented and how much action is recommended.

### If energy is LOW (or past 6pm)

---
**Attention check**
Energy: Low (X msgs, Xm until [next event / end of day])

Take care of yourself first.
- Are you hydrated? Have you eaten?

Top work priority: [single most important/urgent work item — no action recommended unless truly time-sensitive]
Top personal: [single most important personal/reminder item]

Everything else can wait.

---

### If energy is MODERATE (or GAP < 30m)

---
**Attention check**
Energy: Moderate — Xm before [next event / 6pm]

[2–3 items that make sense given time and energy — mix of work and personal, urgent and lightweight]
[Note any blocked/stuck items briefly]

How does your body feel right now?

---

### If energy is FULL and GAP ≥ 30m

---
**Attention check**
Energy: Good — Xm before [next event / 6pm]

[3–4 things worth doing now — mix of work and personal, chosen for fit not urgency alone]
[If something has been waiting and someone else is affected, mention it once, plainly]

Is there anything nagging that isn't on this list?
What do you want to focus on?

---

## Step 4: Work items (always fetch, tune depth to energy)

Always fetch work items regardless of energy level — you need them to identify the top priority shown in Step 3.

Tune what you surface to the energy level: at LOW, identify only the single most important/urgent item (show it in Step 3, don't recommend action unless time-sensitive); at MODERATE, show 1–2 items max and prefer quick wins; at FULL, show up to 3–4 and include longer-horizon items worth starting. Don't list everything — pick the most worth attention given the available gap, and surface them as part of the unified picture in Step 3 — not as a separate dump. Flag a long-waiting or high-impact item if it genuinely deserves a mention, once, without guilt-framing.

### Code review — four categories to check

Use your `code-review` capability to fetch and categorize. Classify each of your open merge requests by what action is needed — your capability has the details on how to read per-reviewer state correctly:

1. **Review requests waiting on you** — someone requested your review
2. **Needs your action** — a reviewer requested changes or left comments; use per-reviewer state, not the aggregate decision
3. **Merge conflicts** — surface these first, dispatch conflict resolution immediately. For stacked branches, also use your `branching` capability to check whether any tracked branches are out of date with their base.
4. **CI failing** — needs investigation or a fix

### Issues — by state

Use your `issues` capability to fetch issues assigned to you, grouped by state (in progress, unstarted, backlog).

### Cross-reference merge requests ↔ issues

After fetching both:

- If an issue has a linked merge request that also appears in the categories above, **group them together** — don't show the same work twice
- Flag if an issue is "In Progress" but its merge request has changes requested or a merge conflict — that's a stuck item

Present as a unified list, grouped by work item (not by tool), with the most actionable status shown.

### Starting work from here

When you decide to act on a work item, use your `agent` capability to dispatch a session — go through the capability's API so that:

- Code reviews always get a worktree sandbox (isolated branch, no risk of clobbering the live repo)
- Sessions are reused when idle rather than spawned fresh every time
- The dispatch is visible in the agent UI

The `agent` capability's dispatch instructions specify exactly how to create worktrees and route sessions.

---

## Usage

Load this skill and say:
- "Come up for air" — runs the full attention check
- "How's my energy?" — just the energy check, no task list
- "What's on my reminders?" — just the reminders step
- "Attention check" — alias for full check

The goal is a gentle, honest picture of where you are — not a to-do list to feel guilty about.
