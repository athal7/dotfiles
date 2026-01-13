---
description: Plan my day - calendar, tasks, and what needs attention
---

Help me plan my day based on my calendar, tasks, and what needs attention.

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
# Agent tasks list
~/.local/bin/remind show 'Agent Tasks'
```

### Granola Meetings

```bash
# Recent meetings (flag ones from last 3 days with notes)
~/.local/bin/granola-cli meetings list 10
```

### macOS Calendar

```bash
# Today's events
icalBuddy -f -ea -nc -nrd eventsToday

# Next 3 days
icalBuddy -f -ea -nc -nrd eventsFrom:today to:today+3
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

## Output

Summarize in priority order:

1. **Urgent** - PRs waiting for my review > 2 days, merge conflicts, blocked items
2. **Today** - PR feedback, meetings, time-sensitive items
3. **This week** - Issues in progress, pending tasks

For each item: what it is (with link), why it needs attention, suggested action.

## Day Planning

Based on all sources, suggest a plan for the day:
1. **Morning** - What to tackle first (urgent items, deep work before meetings)
2. **Around meetings** - Prep needed, buffer time
3. **Afternoon** - Lower priority items, follow-ups

Ask which items I want to work on, then help me tackle them.
