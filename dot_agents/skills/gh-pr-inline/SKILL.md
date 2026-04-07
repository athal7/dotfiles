---
name: gh-pr-inline
description: Post inline comments on GitHub PRs and respond to review feedback via gh api
license: MIT
metadata:
  author: athal7
  version: "1.0"
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

## Approving with Nits

When approving with non-blocking feedback (nits), disable auto-merge so the author has a chance to address them before the PR lands:

```bash
# Disable auto-merge on the PR
gh pr merge --disable-auto {pr_number}
```

Do this **before** posting the review. If auto-merge wasn't enabled, the command is a no-op that exits cleanly.

## Multi-line Comments

For comments spanning lines, add `start_line`:

```json
{"path":"file.rb","start_line":5,"line":10,"body":"This block..."}
```

## Responding to PR Feedback

When addressing reviewer comments after making fixes, **don't reply to every comment**. Use this workflow:

1. **Fixed it?** Resolve the conversation thread (no reply needed).
2. **Not addressing it?** Reply explaining why (disagreement, out of scope, etc.).

### Listing Review Threads

Fetch all threads with their resolution status and comment IDs:

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!) {
    repository(owner:$owner,name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes {
            id
            isResolved
            path
            line
            comments(first:5) {
              nodes { id body author { login } }
            }
          }
        }
      }
    }
  }' -f owner=OWNER -f repo=REPO -F pr=NUMBER
```

### Resolving a Thread (Fixed)

Use the thread's GraphQL `id` (starts with `PRRT_`):

```bash
gh api graphql -f query='
  mutation($id:ID!) {
    resolveReviewThread(input:{threadId:$id}) {
      thread { isResolved }
    }
  }' -f id=PRRT_kwDOxxxxxxx
```

### Replying to a Thread (Not Fixing)

Use the REST API with the **top comment's numeric ID** from the thread:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  --method POST \
  -f body="Intentionally left as-is because..."
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
