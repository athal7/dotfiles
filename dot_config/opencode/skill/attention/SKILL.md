---
name: attention
description: Energy and spoon check — come up for air, see what needs attention without breaking focus
---

# Skill: Attention

Two modes in one skill:

**Passive EA (background):** One LaunchAgent (`ea-meetings`) runs hourly — extracts action items from newly processed meetings and adds them to Work Reminders with a notification. See `ea/` for scripts.

**EA scripts** (`~/.config/opencode/skill/attention/ea/`):
- `post-meeting.sh` — extracts action items from minutes-processed meeting frontmatter → Work Reminders + notification (hourly, working ✅)
- `sync-calendars.applescript` — bidirectional calendar hold sync; works interactively, deferred from LaunchAgent (Calendar TCC issue) 🔜
- `imessage.sh` — notification helper (display notification primary)

**Check-in (on demand):** When you choose to come up for air, this skill surfaces a spoon-aware NOW/NEXT/LATER view.

---

## Step 1: Gather context

Run all of these before forming any view:

```bash
# WakaTime — time coded today
wakatime-cli --today 2>/dev/null

# Calendar — next event and remaining day
# Note: osascript may hang from the OpenCode server process (TCC issue).
# If it hangs after a few seconds, kill it and treat calendar as unknown.
osascript ~/.config/opencode/skill/attention/calendar-today.applescript 2>/dev/null

# Reminders — overdue
remindctl show --json overdue | jq -r '.[] | "OVERDUE: \(.title) [\(.listName)]"'

# Reminders — due today (incomplete only)
remindctl show --json today | jq -r '.[] | select(.isCompleted == false) | "TODAY: \(.title) [\(.listName)]"'

# Reminders — no due date (all priorities, incomplete)
remindctl show --json upcoming | jq -r '.[] |
  select(.isCompleted == false) |
  select(.dueDate == null) |
  "\(.priority // "none"): \(.title) [\(.listName)]"'
```

Note: `remindctl` priority strings are `"high"`, `"medium"`, `"low"`, `"none"` — not integers.

---

## Step 2: Assess the situation holistically

Before surfacing anything, reason across all inputs together:

**Energy (spoons):**

| WakaTime today | Spoon signal |
|----------------|--------------|
| < 2h | Full |
| 2–4h | Moderate |
| > 4h | Low |

**Time available (from calendar):**

- `GAP` = minutes until next event (or rest of day free)
- `END_OF_DAY` = minutes until 6pm
- If GAP < 30m: not enough runway for deep work — suggest quick wins only
- If past 6pm: wind-down mode regardless of WakaTime

**Combined spoon level** — adjust WakaTime signal with calendar context:
- Full spoons + GAP < 30m → treat as Moderate for task suggestions (don't recommend starting a tunnel)
- Low spoons + late in day → reinforce rest, don't push

**Core principle: protect capacity first, output second.**
The goal is sustainable contribution, not maximum throughput. Reducing overwhelm and cognitive load matters more than surfacing every pending item.

**Reminder weighting:**
- All reminders are inputs — but filter ruthlessly before surfacing. Ask: does this need attention *right now*, given current spoons and time?
- Don't stack everything visible. One well-chosen thing is better than five that create paralysis.
- Balance work and personal — a day of only work tasks is a signal, not a success
- No-due-date, no-priority items: only surface if they're a genuine quick win that fits the window, or if they've been waiting long enough that someone else might be affected

**Considerateness without self-sacrifice:**
- If something has been waiting a while and someone else is depending on it, it deserves a mention — but as information, not guilt
- High-priority or long-waiting items get surfaced once, clearly, then dropped. No re-surfacing or nudging in the same session.
- The framing is: "this might matter to someone" not "you should have done this already"

**Monotropism / attentional tunnel awareness:**
- Entering a new tunnel has a cost — only recommend it if GAP is large enough to make it worthwhile
- If already in a tunnel (user just said "coming up for air" mid-session), note the cost of switching vs continuing
- Prefer suggesting task types that match the current cognitive mode
- When in doubt, recommend finishing or resting over starting something new

**Alexithymia prompts** — always include at least one internal-state check, phrased gently:
- At low spoons: "Are you hydrated? Have you eaten?"
- At moderate/full: "How does your body feel right now?" or "Is there anything nagging that isn't on this list?"
- Never frame these as productivity checks — they're genuine care prompts

---

## Step 3: Surface the view

One coherent snapshot — not a stack of sections. Tune depth and length to spoon level.

### If spoons are LOW (or past 6pm)

```
--- Attention check ---
Energy: Low (Xh coded, Xm until [next event / end of day])

Take care of yourself first.
- Are you hydrated? Have you eaten?
- Is there anything with a hard deadline today?

[One actionable thing if truly needed, otherwise nothing]

Everything else can wait.
```

### If spoons are MODERATE (or GAP < 30m)

```
--- Attention check ---
Energy: Moderate — Xm before [next event / 6pm]

[2–3 items that make sense given time and energy — mix of urgent and lightweight]
[Note any blocked/stuck items briefly]

How does your body feel right now?
Anything feel off about this list?
```

### If spoons are FULL and GAP ≥ 30m

```
--- Attention check ---
Energy: Good — Xm before [next event / 6pm]

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

When you decide to act on a work item, offer to open or create an OpenCode session for it rather than leaving you to navigate there manually. The OpenCode web API runs at `http://localhost:4096`.

**Find an existing idle session for a repo:**

```bash
# List sessions for a directory, prefer idle ones
curl -s "http://localhost:4096/session?directory=/Users/athal/code/odin&roots=true" \
  | jq '[.[] | select(.time.archived == null)] | sort_by(.time.updated) | reverse | .[0] | {id, title, directory}'

# Check session statuses (idle = ready to use)
curl -s "http://localhost:4096/session/status" | jq 'to_entries[] | select(.value.type == "idle")'
```

**Reuse an idle session (send a prompt):**

```bash
curl -s -X POST "http://localhost:4096/session/<id>/message?directory=<workingDir>" \
  -H "Content-Type: application/json" \
  -d '{"parts": [{"type": "text", "text": "<prompt>"}]}'
```

**Create a new session (no worktree — use the repo directly):**

```bash
curl -s -X POST "http://localhost:4096/session?directory=/Users/athal/code/<repo>" \
  -H "Content-Type: application/json" -d '{}'
# Then send a message to the returned session id
```

**Create a new worktree sandbox for a PR or issue:**

```bash
# Create worktree (OpenCode picks a name)
curl -s -X POST "http://localhost:4096/experimental/worktree?directory=/Users/athal/code/<repo>" \
  -H "Content-Type: application/json" \
  -d '{"name": "<branch-or-issue-slug>"}'
# Returns: { "name": "...", "directory": "~/.local/share/opencode/worktree/<id>/<name>" }
# Then create a session pointing at that directory
```

**Prefer reuse over creation** — check for an idle session in the target directory first. Only create a new session or worktree if none exists or all are busy.

Once a session is created or identified, load the `process` skill to orchestrate the actual work (plan → implement → verify → commit).

---

## Usage

Load this skill and say:
- "Come up for air" — runs the full attention check
- "How are my spoons?" — just the energy check, no task list
- "What's on my reminders?" — just the reminders step
- "Attention check" — alias for full check

The goal is a gentle, honest picture of where you are — not a to-do list to feel guilty about.
