---
description: Check what needs my attention across all sources
---

Check what needs my attention and help me prioritize.

## Sources

Read `~/.config/opencode/attention-sources.local` for machine-specific data sources (Linear, Reminders, etc). Run each command and gather the results.

### GitHub (always check)

```bash
# PRs needing my review
gh search prs --review-requested=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt

# My open PRs
gh search prs --author=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt

# Issues assigned to me
gh search issues --assignee=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt
```

### PR Details

For each of my open PRs, fetch merge status and comments:

```bash
gh pr view <number> --repo <owner/repo> --json mergeable,mergeStateStatus,comments,reviews,author
```

## Processing Rules

### Merge Conflicts

Flag PRs where `mergeable: "CONFLICTING"` or `mergeStateStatus: "DIRTY"` - these block merging and need rebasing.

### Actionable Feedback

Only flag PRs with comments/reviews that need my attention:

1. **Exclude bots**: `github-actions`, `linear`, `dependabot`, `renovate`, `codecov`, `vercel`, usernames ending in `[bot]`
2. **Exclude my own comments**: filter by PR author login
3. **Include**: Review comments requesting changes, questions from teammates

### What to Skip

- Linear linkback comments (auto-generated issue links)
- Bot automation comments
- My own replies (I already know what I said)
- Approval reviews with no comments

## Output

Summarize what needs attention in priority order:

1. **Urgent** - PRs waiting for my review > 2 days, blocked items, merge conflicts
2. **Today** - PR feedback to address, time-sensitive items
3. **This week** - Issues in progress, pending tasks

For each item, include:
- What it is (with link if available)
- Why it needs attention
- Suggested action

Ask which items I want to work on, then help me tackle them.

## Observability (delegate to `observability` agent)

Check for alerts or anomalies that need attention:

1. **Error spikes** - Services with elevated error rates in the last 24h
2. **Latency degradation** - P95 latency significantly above baseline
3. **Failed transactions** - Recent transaction failures by service

The `observability` agent has Elasticsearch access to query APM indices. Ask it to:
- Check `traces-apm*` for error rate spikes
- Look for services with degraded performance
- Report any anomalies worth investigating

Only include findings that are actionable - skip normal fluctuations.
