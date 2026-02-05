---
name: gh-pr-inline
description: Post inline comments on GitHub PRs via gh api
---

## Why Not `gh pr review`

`gh pr review` doesn't support inline comments on specific lines. Use `gh api` instead.

## Posting Inline Comments

Use `--input -` with heredoc JSON (not `-f 'comments=[...]'` which gets stringified):

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews \
  --method POST \
  --input - << 'EOF'
{
  "event": "REQUEST_CHANGES",
  "comments": [
    {"path":"file.rb","line":10,"body":"Comment text"},
    {"path":"other.rb","line":25,"body":"Another comment"}
  ]
}
EOF
```

## Event Types

- `COMMENT` - Neutral feedback
- `APPROVE` - Approve the PR
- `REQUEST_CHANGES` - Block merge until addressed

## Multi-line Comments

For comments spanning lines, add `start_line`:

```json
{"path":"file.rb","start_line":5,"line":10,"body":"This block..."}
```

## Line Number Gotchas

- Line numbers are file lines in HEAD commit (new file version)
- GitHub's diff display can be off-by-one from what you expect
- Always verify comments landed on the right line after posting
- To delete a misplaced comment: `gh api repos/{owner}/{repo}/pulls/comments/{id} --method DELETE`

## Important Notes

- Omit top-level `body` field to skip summary comment
- Each comment needs: `path`, `line`, `body`
- Safety: Always show proposed comments and wait for approval before posting
