---
description: What needs my attention right now
---

Show me what needs attention based on my calendar, PRs, and recent meetings.

> **Profile required**: `product` - Start session with `OPENCODE_CONFIG=~/.config/opencode/profiles/product.json` to enable Linear and Granola MCPs.

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

For each of my open PRs, fetch merge status, CI status, comments, and linked issues:

```bash
gh pr view <number> --repo <owner/repo> --json mergeable,mergeStateStatus,statusCheckRollup,comments,reviews,author,closingIssuesReferences,labels
```

**Important:** Also fetch review thread comments (inline code comments) which are NOT included in the above:

```bash
gh api repos/<owner>/<repo>/pulls/<number>/comments
```

This returns inline code review comments with `user.login`, `body`, `path`, `line`, and `created_at`.

For PRs needing review, also fetch linked issues to understand priority:

```bash
gh pr view <number> --repo <owner/repo> --json closingIssuesReferences,labels
```

### Linear

Delegate to the `pm` agent to fetch Linear issues:

> Fetch my assigned Linear issues that are In Progress, In Review, or Todo (limit 20). Return:
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

### PR-Issue Linking

**Extract issue IDs from PRs:**
1. Parse PR title for issue ID patterns: `feat(ABC-123):`, `fix(ABC-123):`, `(ABC-123)`, etc.
2. Check `closingIssuesReferences` from `gh pr view` for GitHub issue links
3. Build a map: `PR # → Issue ID`

**Cross-reference with Linear:**
1. Match extracted issue IDs against the Linear issues returned
2. If a PR's issue ID matches a Linear issue, inherit its priority and status
3. If a PR references an issue ID NOT in the Linear results, note it as "issue not in active backlog"

**Output format for linked PRs:**
- `PR #123 → PROJ-456 (P2 High, In Progress)` — when Linear issue found
- `PR #124 (no issue linked)` — when no issue ID in title
- `PR #125 → PROJ-789 (not in active backlog)` — when issue ID found but not in Linear results

### Priority Ranking

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

**Inherited priority**: PRs inherit priority from their linked Linear issues.

### Merge Conflicts

Flag PRs where `mergeable: "CONFLICTING"` or `mergeStateStatus: "DIRTY"`.

### CI Status

Check `statusCheckRollup` for each PR:
- **Failing (🔴)**: Any check with `conclusion: "FAILURE"` — requires immediate attention
- **Pending**: Any check with `status: "IN_PROGRESS"` or `status: "PENDING"` — note as "CI running"
- **Passing**: All checks `conclusion: "SUCCESS"` or `"SKIPPED"` — show as "✅ CI green"

CI failures are urgent and should be prioritized above PRs awaiting review.

### Actionable Feedback (Critical)

There are THREE types of comments to check:
1. **PR-level comments** (`comments` from `gh pr view`) — general discussion
2. **Reviews** (`reviews` from `gh pr view`) — formal review submissions
3. **Review thread comments** (`gh api .../pulls/{n}/comments`) — inline code comments ⚠️ MOST IMPORTANT

**Completely ignore:**
- Comments where `isMinimized: true` (outdated, resolved, off-topic)
- Comments from bots: `github-actions`, `linear`, `dependabot`, any author with `[bot]` suffix or `is_bot: true`
- My own comments (match by `viewerDidAuthor: true` or author login)

**Reviews requiring action (🔴):**
- `state: "CHANGES_REQUESTED"` — always requires action
- My own review comments flagging work needed (e.g., "Missing tests") — self-assigned action item

**Reviews that are NOT actionable:**
- `state: "APPROVED"` — no action needed
- `state: "COMMENTED"` with empty `body` — this is just an acknowledgment/view, not feedback

**Review thread comments (inline code comments) requiring attention (⏰):**
- Any non-bot comment from the `gh api repos/.../pulls/{n}/comments` endpoint
- These are code review feedback and almost always need a response
- Summarize by count and reviewer: "4 comments from @reviewer"
- Show brief excerpts of the feedback

**PR-level comments requiring attention (⏰):**
- Non-bot, non-minimized comments containing questions (look for `?`)
- Non-bot, non-minimized comments requesting changes or action

**Comments that are NOT actionable:**
- Bot comments (even if not minimized)
- My own comments (unless flagging work I need to do)

### Calendar

Use today's events to help prioritize - flag meeting conflicts, prep time needed.

### Meeting Action Items

Include action items from yesterday's meetings - especially items assigned to me or unassigned.

## Output

Single flat list, one line per item, **sorted by priority** (highest first within each urgency tier). Use markers:
- `🔴` urgent (CI failing, CHANGES_REQUESTED, conflicts, P0/P1)
- `⏰` time-sensitive today (has questions/feedback to address, meetings soon)
- `📋` can do anytime (CI green, awaiting review, no blockers)

**PR format:**
```
🔴 PR #123 → PROJ-456 (P2 High) — ❌ CI failing, self-review: "Missing system tests" [link]
🔴 PR #125 → PROJ-789 (not in backlog) — ❌ CI failing [link]
⏰ PR #126 → PROJ-101 (P2 High) — ✅ CI green, 3 comments from @reviewer [link]
📋 PR #124 (no issue) — ✅ CI green, awaiting review [link]
```

**Do NOT flag as needing attention:**
- PRs with only bot comments
- PRs with only `COMMENTED` reviews that have empty bodies
- PRs with only minimized/outdated comments

Include link at end of line. Adapt list length to time remaining in workday (assume 5-6pm end) - shorter list later in day. If light, include unscheduled reminders as options.

Ask which I want to work on.
