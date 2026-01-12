---
description: Check what needs my attention across all sources
agent: plan
---

Check what needs my attention and help me prioritize.

## Sources

Read `~/.config/opencode/attention-sources.local` for machine-specific data sources and commands. Run each command and gather the results.

If the file doesn't exist, fall back to these generic GitHub checks:

```bash
# PRs needing my review
gh search prs --review-requested=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt

# My open PRs (we'll check for human comments separately)
gh search prs --author=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt

# Issues assigned to me
gh search issues --assignee=@me --state=open --limit=20 --json=number,title,url,repository,updatedAt
```

## Filtering Comments

For each PR, fetch comments and filter out bots AND the PR author (your own comments don't need your attention):

```bash
# Get comments for a specific PR, filter out bots and PR author
gh pr view <number> --repo <owner/repo> --json author,comments --jq '.author.login as $author | [.comments[] | select(.author.login != $author) | select(.author.login | test("\\[bot\\]$|^github-actions$|^dependabot$|^renovate$|^codecov$|^vercel$|^linear$"; "i") | not)] | length'
```

Exclude:
- PR author's own comments
- Usernames ending in `[bot]`
- `github-actions`, `dependabot`, `renovate`, `codecov`, `vercel`, `linear`

Only flag PRs that have comments **from others** as needing attention.

## Output

Summarize what needs attention in priority order:

1. **Urgent** - PRs waiting for my review > 2 days, blocked items
2. **Today** - PR feedback to address, time-sensitive items
3. **This week** - Issues in progress, pending tasks

For each item, include:
- What it is (with link if available)
- Why it needs attention
- Suggested action

Ask which items I want to work on, then help me tackle them.
