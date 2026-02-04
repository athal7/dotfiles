---
name: gh-pr-inline
description: Post inline comments on GitHub PRs via gh api
---

## Why Not `gh pr review`

`gh pr review` doesn't support inline comments on specific lines. Use `gh api` instead.

## Posting Inline Comments

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews \
  --method POST \
  -f event="COMMENT" \
  -f 'comments=[{"path":"file.rb","line":10,"body":"Comment text"}]'
```

## Event Types

- `COMMENT` - Neutral feedback
- `APPROVE` - Approve the PR
- `REQUEST_CHANGES` - Block merge until addressed

## Multi-line Comments

For comments spanning lines, add `start_line`:

```bash
-f 'comments=[{"path":"file.rb","start_line":5,"line":10,"body":"This block..."}]'
```

## Important Notes

- **Line numbers must be from actual files** (use Read tool), not diff positions
- Omit top-level `body` field to skip summary comment
- Each comment needs: `path`, `line`, `body`
- Safety: Always show proposed comments and wait for approval before posting
