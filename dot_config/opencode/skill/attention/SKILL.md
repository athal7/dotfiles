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

```bash
# Requires LINEAR_API_KEY in env (loaded via direnv from ~/.env)
gq https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -q '{
    viewer {
      assignedIssues(filter: { state: { type: { in: ["started", "unstarted"] } } }, first: 20) {
        nodes {
          identifier title
          state { name type }
          priority
          url
          attachments(first: 5) { nodes { url title } }
        }
      }
    }
  }' | jq '.data.viewer.assignedIssues.nodes[] | {
    id: .identifier,
    title,
    state: .state.name,
    priority,
    url,
    prs: [.attachments.nodes[] | select(.url | contains("github.com")) | .url]
  }'
```

### Cross-reference GitHub ↔ Linear

Linear issues surface GitHub PR URLs in their attachments. After fetching both:

- If a Linear issue has a linked PR that also appears in the GitHub categories above, **group them together** — don't show the same work twice
- Flag if a Linear issue is "In Progress" but its PR has `CHANGES_REQUESTED` or `DIRTY` — that's a stuck item needing attention
- Flag if a PR is ready for review but has no linked Linear issue — may be untracked work

Present as a unified list, grouped by work item (not by tool), with the most actionable status shown.

---

## Usage

Load this skill and say:
- "Come up for air" — runs the full attention check
- "How are my spoons?" — just the energy check, no task list
- "What's on my reminders?" — just the reminders step
- "Attention check" — alias for full check

The goal is a gentle, honest picture of where you are — not a to-do list to feel guilty about.
