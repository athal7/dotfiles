---
description: What needs my attention right now
---

Show me what needs attention based on my calendar, PRs, and recent meetings.

First, check the current time:

```bash
date "+%H:%M %A"
```

Use this to contextualize what's relevant NOW vs later.

## Sources

Run each command below. Skip sections gracefully if a tool isn't available.

### GitHub

```bash
# PRs needing my review
gh search prs --review-requested=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt

# My open PRs
gh search prs --author=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt

# Issues assigned to me
gh search issues --assignee=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt
```

For each of my open PRs, fetch merge status and comments:

```bash
gh pr view <number> --repo <owner/repo> --json mergeable,mergeStateStatus,comments,reviews,author
```

### Linear (if LINEAR_API_KEY set)

```bash
# In-progress issues (filter to my assignments in output)
linearis issues search "" --status "In Progress" --limit 20
```

### Apple Reminders

```bash
# All reminders (includes unscheduled)
~/.local/bin/remind show
```

### Granola Meetings

```bash
# Recent meetings (flag ones from last 3 days with notes)
~/.local/bin/granola-cli meetings list 10
```

For meetings from **yesterday** that have notes (`has_notes: true`), delegate to the `context` agent to fetch full meeting details and extract action items:

> Fetch meeting notes for [meeting ID] and extract:
> - Action items (especially any assigned to Andrew/me)
> - Key decisions or commitments made
> - Open questions or blockers mentioned

Meetings from the last 3 days are listed for context (relating to current work), but only check yesterday's for new action items.

### macOS Calendar

```bash
# Remaining events today and tomorrow
icalBuddy -f -ea -nc -nrd eventsFrom:today to:today+1
```

## Processing Rules

### Merge Conflicts

Flag PRs where `mergeable: "CONFLICTING"` or `mergeStateStatus: "DIRTY"`.

### Actionable Feedback

Only flag comments/reviews needing attention:
- **Exclude**: bots (`github-actions`, `linear`, `dependabot`, `[bot]`), my own comments, approval-only reviews
- **Include**: Change requests, questions from teammates

### Calendar

Use today's events to help prioritize - flag meeting conflicts, prep time needed.

### Meeting Action Items

Include action items from yesterday's meetings - especially items assigned to me or unassigned.

## Output

Single flat list, one line per item. Use markers:
- `🔴` urgent (overdue, blocking others, conflicts)
- `⏰` time-sensitive today
- `📋` can do anytime

Include link at end of line. Adapt list length to time remaining in workday (assume 5-6pm end) - shorter list later in day. If light, include unscheduled reminders as options.

Ask which I want to work on.
