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
gh search prs --review-requested=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt,labels

# My open PRs
gh search prs --author=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt,labels

# Issues assigned to me
gh search issues --assignee=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt,labels
```

For each of my open PRs, fetch merge status, comments, and linked issues:

```bash
gh pr view <number> --repo <owner/repo> --json mergeable,mergeStateStatus,comments,reviews,author,closingIssuesReferences,labels
```

For PRs needing review, also fetch linked issues to understand priority:

```bash
gh pr view <number> --repo <owner/repo> --json closingIssuesReferences,labels
```

### Linear

Delegate to the `pm` agent to fetch Linear issues:

> Fetch my assigned Linear issues that are In Progress or Todo (limit 20). Return:
> - Issue ID (e.g., ABC-123)
> - Title
> - Status
> - Priority (1=urgent, 2=high, 3=medium, 4=low, 0=none)
> - URL
>
> Format as JSON array.

Use priority to rank items in the final output.

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

### PR-Issue Relationships

Link PRs to their associated issues/tickets to understand context and priority:

- **GitHub**: Use `closingIssuesReferences` from `gh pr view` to find linked issues
- **Linear**: Match PR titles/branches containing issue IDs (e.g., `ABC-123`) to Linear issues
- **Convention**: PR branches often follow `<type>/<ISSUE-ID>-description` pattern

When a PR is linked to an issue, inherit the issue's priority for ranking.

### Priority Ranking

Prioritize items based on issue/ticket priority:

**GitHub labels** (look for these patterns):
- `priority: critical`, `P0`, `urgent` → highest
- `priority: high`, `P1` → high
- `priority: medium`, `P2` → medium
- `priority: low`, `P3`, `P4` → low

**Linear priority** (numeric):
- 1 (Urgent) → highest
- 2 (High) → high
- 3 (Medium) → medium
- 4 (Low) → low
- 0 (No priority) → medium (default)

**Inherited priority**: PRs inherit priority from their linked issues. A PR fixing a P1 bug is higher priority than a PR for a P3 feature.

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

Single flat list, one line per item, **sorted by priority** (highest first within each urgency tier). Use markers:
- `🔴` urgent (overdue, blocking others, conflicts, P0/P1 issues)
- `⏰` time-sensitive today
- `📋` can do anytime

For PRs linked to issues, show the relationship: `PR #123 (fixes PROJ-456 P1)` or `PR #123 → #45 high`.

Include link at end of line. Adapt list length to time remaining in workday (assume 5-6pm end) - shorter list later in day. If light, include unscheduled reminders as options.

Ask which I want to work on.
