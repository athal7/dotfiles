---
name: attention
description: Energy and spoon check — come up for air, see what needs attention without breaking focus
---

# Skill: Attention

**Check-in (on demand):** When you choose to come up for air, this skill surfaces a spoon-aware NOW/NEXT/LATER view.

**Calendar access:** `icalbuddy` — fast, reads directly from the local calendar cache.

---

## Step 1: Gather context

Run all of these before forming any view:

```bash
# OpenCode sessions today — cognitive load metrics
# Filters out subagent noise (worktree paths + "@... subagent" titles)
DB=~/.local/share/opencode/opencode.db
SKILL_DIR=~/.config/opencode/skill/attention

# Per-session breakdown: user messages (= your active engagement) + duration
sqlite3 -json "$DB" < $SKILL_DIR/sessions-today.sql \
  | jq -r '.[] | "SESSION [\(.repo)] \(.user_messages) msgs \(.duration_min)m — \(.title)"'

# Summary totals + peak concurrent
sqlite3 "$DB" < $SKILL_DIR/sessions-summary.sql
sqlite3 "$DB" < $SKILL_DIR/sessions-concurrent.sql

# Calendar — today's events, personal calendars only (work events come from gws)
# -ic: limit to personal calendars  -nrd: no relative dates  -iep: title+datetime only
PERSONAL_CALS="Me,105,Rebecca,Birthdays,US Holidays,Jewish Holidays"
echo "DAY_OF_WEEK: $(date +%A) TIME: $(date +%H:%M)"
icalbuddy -ic "$PERSONAL_CALS" -nrd -b "" -iep "title,datetime" eventsToday 2>/dev/null

# Reminders — overdue
remindctl show --json overdue | jq -r '.[] | "OVERDUE: \(.title) [\(.listName)]"'

# Reminders — due today (incomplete only)
remindctl show --json today | jq -r '.[] | select(.isCompleted == false) | "TODAY: \(.title) [\(.listName)]"'

# Reminders — no due date (all priorities, incomplete)
# Note: `upcoming` only returns items with future due dates — use `all` for no-due-date items
remindctl show --json all | jq -r '.[] |
  select(.isCompleted == false) |
  select(.dueDate == null) |
  "\(.priority // "none"): \(.title) [\(.listName)]"'

# Meeting notes — today's processed meetings (for social/emotional load inference)
TODAY=$(date +%Y-%m-%d)
minutes list --limit 20 | jq -r ".[] | select(.date | startswith(\"$TODAY\")) | \"MEETING: \(.title) @ \(.date)\""

# Slack — recent mentions waiting on you (last 8h)
source ~/.env
SINCE=$(date -v-8H +%s 2>/dev/null || date -d '8 hours ago' +%s)
curl -s "https://slack.com/api/search.messages?query=<@$SLACK_USER_ID>&count=10&sort=timestamp" \
  -H "Authorization: Bearer $SLACK_USER_TOKEN" \
  | jq -r ".messages.matches[] | select((.ts | split(\".\")[0] | tonumber) > $SINCE) | \"MENTION: \(.channel.name) — \(.username): \(.text | .[0:120])\""
```

Note: `remindctl` priority strings are `"high"`, `"medium"`, `"low"`, `"none"` — not integers.

---

## Step 2: Assess the situation holistically

Before surfacing anything, reason across all inputs together.

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
- Cross-repo jumps (dotfiles → odin → dotfiles) compound the switching cost
- Check earliest session start — a long elapsed day is tiring even at low intensity

**Interoceptive caveat:** With alexithymia, the body often doesn't signal depletion until it's too late. These metrics are proxies. Treat high output as a *warning* signal, not a green light — boom-and-bust cycles start by overdoing it on good days.

**Spoon table — use the worse of the two signals:**

| User messages today | Spoon signal |
|---------------------|--------------|
| < 20 | Likely available |
| 20–60 | Moderate |
| 60–120 | Caution |
| > 120 | Low |

| Peak concurrent sessions | Modifier |
|--------------------------|----------|
| 1 | No change |
| 2–3 | +1 level toward Low |
| 4+ | +2 levels toward Low (cap at Low) |

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

```
--- Attention check ---
Energy: Low (Xm in sessions, Xm until [next event / end of day])

Take care of yourself first.
- Are you hydrated? Have you eaten?
- Is there anything with a hard deadline today?

[One actionable thing if truly needed, otherwise nothing]

Everything else can wait.
```

### If spoons are MODERATE (or GAP < 30m)

```
--- Attention check ---
Energy: Moderate (Xm in sessions) — Xm before [next event / 6pm]

[2–3 items that make sense given time and energy — mix of urgent and lightweight]
[Note any blocked/stuck items briefly]

How does your body feel right now?
Anything feel off about this list?
```

### If spoons are FULL and GAP ≥ 30m

```
--- Attention check ---
Energy: Good (Xm in sessions) — Xm before [next event / 6pm]

[1–2 things worth doing now — chosen for fit, not for urgency alone]
[If something has been waiting and someone else is affected, mention it once, plainly]
[One personal item if only work is surfacing]

Is there anything nagging that isn't on this list?
What do you want to focus on?
```

---

## Step 4: Work items (spoons FULL only)

If spoons are not FULL, skip this step entirely. Don't mention the backlog — it can wait.

When spoons are FULL, don't list everything. Pick the 1–2 work items most worth attention given the available gap, and surface them as part of the unified picture in Step 3 — not as a separate dump. Flag a long-waiting or high-impact item if it genuinely deserves a mention, once, without guilt-framing.

### GitHub PRs — four categories to check

```bash
# 1. Review requested from you
gh api "search/issues?q=is:pr+is:open+review-requested:@me&per_page=10" \
  --jq '.items[] | "  REVIEW: \(.title) \(.html_url)"'

# 2. Your PRs with changes requested
gh api "search/issues?q=is:pr+is:open+author:@me+review:changes-requested&per_page=10" \
  --jq '.items[] | "  CHANGES: \(.title) \(.html_url)"'

# 3. Your PRs with merge conflicts (check mergeStateStatus per repo)
# mergeStateStatus=DIRTY means conflicts; requires per-repo query
gh pr list -R 0din-ai/odin --author @me \
  --json number,title,mergeStateStatus,headRefName \
  --jq '.[] | select(.mergeStateStatus == "DIRTY") | "  CONFLICT: \(.title) (#\(.number))"'
# Repeat for other active repos as needed

# 4. Your PRs awaiting review (no decision yet, not draft)
gh api "search/issues?q=is:pr+is:open+author:@me+review:required&per_page=10" \
  --jq '.items[] | "  WAITING: \(.title) \(.html_url)"'
```

### Linear — issues by state

```bash
source ~/.env
SKILL_DIR=~/.config/opencode/skill/attention
gq https://api.linear.app/graphql -H "Authorization: $LINEAR_API_KEY" \
  --queryFile $SKILL_DIR/team-issues.gql -v teamId="$LINEAR_TEAM_ID" \
  | jq '.data.team.issues.nodes'
```

### Cross-reference GitHub ↔ Linear

After fetching both:

- If a Linear issue has a linked PR that also appears in the GitHub categories above, **group them together** — don't show the same work twice
- Flag if a Linear issue is "In Progress" but its PR has `CHANGES_REQUESTED` or `DIRTY` — that's a stuck item
- Flag if a PR is ready for review but has no linked Linear issue — may be untracked work

Present as a unified list, grouped by work item (not by tool), with the most actionable status shown.

### Starting work from here

When you decide to act on a work item, load the `dispatch` skill to open or reuse an OpenCode session in the target repo.

---

## Usage

Load this skill and say:
- "Come up for air" — runs the full attention check
- "How are my spoons?" — just the energy check, no task list
- "What's on my reminders?" — just the reminders step
- "Attention check" — alias for full check

The goal is a gentle, honest picture of where you are — not a to-do list to feel guilty about.
