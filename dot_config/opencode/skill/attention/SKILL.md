---
name: attention
description: Energy and spoon check — come up for air, see what needs attention without breaking focus
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

```bash
wakatime-cli --today 2>/dev/null | head -5
osascript "$(dirname $0)/calendar-today.applescript"
```

The calendar script returns structured `GAP:`, `END_OF_DAY:`, and `EVENT:` lines. Use both outputs together to synthesize spoon level:

| WakaTime today | Remaining events | Spoon level |
|---------------|-----------------|-------------|
| < 2h | 0–1 | Full |
| 2–4h | 1–2 | Moderate |
| > 4h | any | Low |
| any | 3+ | Low |

---

## Step 2: Read Apple Reminders

```bash
osascript "$(dirname $0)/reminders-due.applescript"
```

The script returns reminders grouped by urgency:

| Prefix | Meaning |
|--------|---------|
| `BLOCKED` | Flagged — waiting on something external, not actionable right now |
| `OVERDUE` | Past due date |
| `TODAY` | Due today |
| `HIGH` | No due date, high priority |
| `MEDIUM` | No due date, medium priority — only surface if spoons allow |

BLOCKED items should be shown separately — they're not tasks to act on, just things to be aware of.
Items with no due date and no priority set are not surfaced (no signal they matter now).

---

## Step 3: Surface the view

Present a **NOW / NEXT / LATER** view, scaled to spoon level. Use the GAP and END_OF_DAY values from `calendar-today.applescript` to frame how much time is available.

### If spoons are LOW

```
--- Attention check ---
Energy: Low (coded Xh today, Xm until next event / end of day)

Take care of yourself first.
- Are you hydrated?
- Have you eaten?
- Is there anything with a hard deadline today?

One thing if needed: [single OVERDUE or TODAY item, if any]

Everything else can wait. You've done enough.
```

### If spoons are MODERATE

```
--- Attention check ---
Energy: Moderate — Xm available before [next event / 6pm]

NOW (needs action today):
  • [BLOCKED items — visible but not actionable, max 2]
  • [OVERDUE + TODAY reminders, max 2]
  • [Next calendar event with time]

NEXT (on your radar):
  • [HIGH priority reminders, max 2]

Anything feel off about this list?
```

### If spoons are FULL

```
--- Attention check ---
Energy: Good — Xm available before [next event / 6pm]

NOW:
  • [BLOCKED items]
  • [OVERDUE + TODAY reminders, max 3]
  • [Calendar items starting soon]

NEXT:
  • [HIGH priority reminders, max 3]

LATER (lower signal, just visible):
  • [MEDIUM priority reminders, max 2]

What do you want to focus on?
```

---

## Step 4: Work items (spoons FULL only)

If spoons are not FULL, skip this step and note:
> "Work items are waiting — check in when you have more capacity."

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

Load the `linear` skill for auth setup and query patterns, then fetch assigned issues in `started` or `unstarted` states, including their attachments (which surface linked PR URLs).

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
