---
description: Prepare standup answers from recent activity
---

Help me prepare for standup by answering these questions based on my recent activity.

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

### Linear (if LINEAR_API_KEY set)

```bash
# My issues - completed recently
linearis issues search "" --status "Done" --limit 10

# My issues - in progress
linearis issues search "" --status "In Progress" --limit 10

# My issues - blocked or on hold
linearis issues search "" --status "Blocked" --limit 10
```

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
```

## Processing Rules

### Progress (Since Last Standup)

Look back ~24 hours (or since Friday if it's Monday):
- PRs merged or significantly updated
- Issues completed or moved to review
- Code reviews completed
- Meetings with key decisions

### Today's Plan

Based on:
- Open PRs that need attention (reviews received, conflicts)
- In-progress issues
- Today's calendar (meetings, focus time)
- Reminders/tasks due

### Blockers

Flag anything where:
- PR is waiting on review > 2 days
- Issue is marked blocked
- Dependency on someone else's work
- Need decision or clarification

For each blocker, suggest who might help (based on PR reviewers, issue assignees, or meeting attendees).

### Fun Highlights

Look for:
- Interesting technical wins or learnings
- Good discussions in meetings
- Shipped features users will notice
- Team moments from Slack/meetings

## Output

Draft standup answers in this format:

---

**Progress since last standup:**
- [Bullet points of completed/progressed work with links]

**Plan for today:**
- [Bullet points of what you'll work on]

**Blockers:**
- [Any blockers with specific asks and suggested @mentions, or "None"]

**Fun highlight:**
- [One thing that was fun or interesting]

---

Present the draft for my review. I may want to adjust tone or add context before posting.
