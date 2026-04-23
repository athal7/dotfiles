---
name: gh
description: GitHub CLI integration — non-obvious behavior for PRs, reviews, CI, and repo queries
license: MIT
compatibility: opencode
metadata:
  provides:
    - source-control
    - ci
---

# Skill: gh

GitHub CLI (`gh`) gotchas that `--help` won't tell you.

## Review state — what the fields actually mean

`reviewDecision` is an aggregate and loses per-reviewer signal — do not use it to determine if a merge request is waiting on the reviewer vs the author. Use `latestReviews[].state` instead:

| State | Action needed by |
|---|---|
| `CHANGES_REQUESTED` | **Author** — reviewer wants changes addressed |
| `APPROVED` | Nobody — this reviewer is satisfied |
| `COMMENTED` | Ambiguous — reviewer left comments but no formal verdict |

## Detecting merge requests that need your attention

Use this query to find your open merge requests needing action in a single call:

```bash
gh pr list --author=@me --state=open --repo <owner>/<repo> \
  --json number,title,url,mergeStateStatus,latestReviews,commits,reviewRequests
```

Or cross-repo via GraphQL:

```bash
gh api graphql -f query='{ viewer { pullRequests(first: 20, states: OPEN) { nodes {
  number title url
  repository { nameWithOwner }
  mergeStateStatus
  reviewRequests(first: 10) { nodes { requestedReviewer { ... on User { login } } } }
  latestReviews(first: 10) { nodes { state authorAssociation author { login } submittedAt } }
  commits(last: 1) { nodes { committedDate } }
} } } }'
```

### What needs action

Check each open merge request for these conditions — surface any that match:

1. **Merge conflict** — `mergeStateStatus == "DIRTY"` — highest priority, surface first
2. **CI failing** — `mergeStateStatus == "UNSTABLE"`
3. **Re-review not requested** — a reviewer has `COMMENTED` or `CHANGES_REQUESTED` in `latestReviews`, their `authorAssociation != "NONE"` (excludes bots), their `submittedAt` is before your last commit (`commits[-1].committedDate`), and they are not already in `reviewRequests` — you pushed a response but haven't asked them to look again



## `mergeStateStatus` values

| Value | Means |
|---|---|
| `CLEAN` | No conflicts, branch protection satisfied |
| `DIRTY` | Has merge conflicts — surface first, fix immediately |
| `UNSTABLE` | CI is failing |
| `BLOCKED` | Branch protection rules not satisfied (e.g. required review not yet approved) — **does not mean conflict** |
| `BEHIND` | Branch is behind the base branch |
| `HAS_HOOKS` | Mergeable with passing commit status and pre-receive hooks |
| `UNKNOWN` | State cannot currently be determined — retry or use per-repo `gh pr list` |

`BLOCKED` + `mergeable: MERGEABLE` = branch protection (missing required approval), not a conflict. Do not file as a merge conflict.

## Cross-repo activity summary (`gh status`)

`gh status` returns a formatted summary across all repositories you're subscribed to:

- **Assigned Issues** — issues assigned to you
- **Assigned Pull Requests** — merge requests assigned to you
- **Review Requests** — merge requests where your review is requested
- **Mentions** — threads where you were @-mentioned (issues, PRs, discussions)
- **Repository Activity** — recent comments and new issues/PRs in repos you watch

Use `--org <org>` to scope to a specific organization. Use `-e <owner/repo>` to exclude noisy repos.

This is the right command for surfacing mentions and review requests — it maps directly to what GitHub's notification bell shows.

## Checking repo visibility

```bash
gh repo view --json visibility -q '.visibility'
```

## CI status

```bash
# Latest run on a branch
gh run list --branch <branch> --limit 1

# Failed step logs
gh run view <run-id> --log-failed
```

## Inline Review Comments

`gh pr review` doesn't support inline comments on specific lines. Use `gh api` instead.

### Posting Inline Comments

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

Event types: `COMMENT`, `APPROVE`, `REQUEST_CHANGES`.

### Approving with Nits

When approving with non-blocking feedback (nits), disable auto-merge so the author has a chance to address them before the merge lands:

```bash
gh pr merge --disable-auto {pr_number}
```

Do this **before** posting the review. If auto-merge wasn't enabled, the command is a no-op that exits cleanly.

### Multi-line Comments

```json
{"path":"file.rb","start_line":5,"line":10,"body":"This block..."}
```

### Responding to Review Feedback

When addressing reviewer comments after making fixes:

1. **Fixed it?** Resolve the conversation thread (no reply needed).
2. **Not addressing it?** Reply explaining why.

**Push before resolving.** GitHub ties thread resolution to the commit that addressed it.

### Listing Review Threads

```bash
gh api graphql -f query='
  query($owner:String!,$repo:String!,$pr:Int!) {
    repository(owner:$owner,name:$repo) {
      pullRequest(number:$pr) {
        reviewThreads(first:100) {
          nodes {
            id isResolved path line
            comments(first:5) {
              nodes { id body author { login } }
            }
          }
        }
      }
    }
  }' -f owner=OWNER -f repo=REPO -F pr=NUMBER
```

### Resolving a Thread

```bash
gh api graphql -f query='
  mutation($id:ID!) {
    resolveReviewThread(input:{threadId:$id}) {
      thread { isResolved }
    }
  }' -f id=PRRT_kwDOxxxxxxx
```

### Replying to a Thread

Use the REST API with the **top comment's numeric ID**:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments/{comment_id}/replies \
  --method POST \
  -f body="Intentionally left as-is because..."
```

### Line Number Gotchas

- Line numbers are file lines in HEAD commit (new file version)
- GitHub's diff display can be off-by-one from what you expect
- To delete a misplaced comment: `gh api repos/{owner}/{repo}/pulls/comments/{id} --method DELETE`

### Notes

- Omit top-level `body` field to skip summary comment
- Each comment needs: `path`, `line`, `body`
- Always show proposed comments and wait for approval before posting
