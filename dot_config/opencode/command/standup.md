---
description: Prepare standup answers from recent activity
---

Help me prepare for standup by answering these questions based on my recent activity.

> **Profile required**: `product` - Start session with `OPENCODE_CONFIG=~/.config/opencode/profiles/product.json` to enable Linear and Granola MCPs.

## Questions

1. **What progress have you made since last standup?**
2. **What do you expect to complete today?**
3. **Anything blocking your progress that you need an assist with?** Be specific and consider a follow-up thread including an @ for anyone that can assist.
4. **What is something fun that happened this week?**

## Sources

Run each command below. Skip sections gracefully if a tool isn't available.

### GitHub (Private repos only)

```bash
# My recently merged PRs (last 7 days) - private repos only
gh search prs --author=@me --merged --merged-at=">=$(date -v-7d +%Y-%m-%d)" --visibility=private --limit=10 --json=number,title,url,repository,closedAt

# My open PRs (in progress work) - private repos only
gh search prs --author=@me --state=open --visibility=private --limit=10 --json=number,title,url,repository,updatedAt

# PRs I reviewed recently - private repos only
gh search prs --reviewed-by=@me --updated=">=$(date -v-2d +%Y-%m-%d)" --visibility=private --limit=10 --json=number,title,url,repository,state
```

### Linear

Delegate to the `pm` agent to fetch Linear issues:

> Fetch my assigned Linear issues in these statuses: Done (last 7 days), In Progress, and Blocked. Return for each:
> - Issue ID (e.g., ABC-123)
> - Title
> - Status
> - Priority
> - URL
>
> Format as JSON array grouped by status.

### Granola Meetings

```bash
# Recent meetings for context on discussions/decisions
~/.local/bin/granola-cli meetings list 5
```

For meetings from **yesterday** with notes (`has_notes: true`), delegate to the `context` agent to extract:
- Decisions made
- Fun moments or highlights
- Commitments I made

### macOS Calendar

```bash
# Today's schedule (for planning what to complete)
icalBuddy -f -ea -nc -nrd eventsToday

# Recent personal events for fun highlight (last 7 days)
# Look for non-work events: social, sports, concerts, travel, etc.
icalBuddy -f -nc -nrd eventsFrom:"$(date -v-7d +%Y-%m-%d)" to:"$(date +%Y-%m-%d)"
```

## Processing Rules

### Framing

**Talk in terms of tickets and outcomes, not GitHub activity.** PRs are implementation details - focus on what was accomplished for each issue and the user-facing or business impact.

### Progress (Since Last Standup)

Look back ~24 hours (or since Friday if it's Monday). Group by ticket:
- Extract ticket IDs from PR titles (e.g., `PROJ-123`, `ABC-456`)
- Summarize what was accomplished for each ticket, not individual PRs
- For PRs without tickets, describe the outcome (bug fixed, performance improved, etc.)
- Include key decisions from meetings

### Today's Plan

Based on:
- In-progress tickets (from Linear or PR titles)
- What's needed to close those tickets
- Today's calendar (meetings, focus time)

### Blockers

Flag anything where:
- Ticket is explicitly blocked
- Waiting on someone else > 2 days (review, decision, dependency)
- Need clarification on requirements

For each blocker, suggest who might help (based on PR reviewers, issue assignees, or meeting attendees).

### Fun Highlights

This should be something **personal**, not work-related. Scan recent calendar events and filter out obvious work meetings (standups, syncs, 1:1s, interviews). Look for:
- Social events, dinners, hangouts
- Sports, concerts, shows, games
- Hobbies, classes, activities
- Travel or day trips
- Holidays or celebrations

If no personal events found in calendar, ask the user what fun thing happened this week.

## Output

Draft standup answers in this format:

---

**Progress since last standup:**
- [Ticket ID]: [What was accomplished/outcome] ([link])
- [Description of non-ticket work if any]

**Plan for today:**
- [Ticket ID]: [What needs to happen to close it]
- [Other planned work]

**Blockers:**
- [Any blockers with specific asks and suggested @mentions, or "None"]

**Fun highlight:**
- [One thing that was fun or interesting]

---

Present the draft for my review. I may want to adjust tone or add context before posting.
