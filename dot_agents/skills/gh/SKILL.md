---
name: gh
description: GitHub CLI integration — non-obvious behavior for PRs, reviews, CI, and repo queries
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - source-control
    - ci
---

# Skill: gh

GitHub CLI (`gh`) gotchas that `--help` won't tell you.

## Review state — what the fields actually mean

### `reviewDecision` (aggregate)

The overall decision across all reviewers. Values:

| Value | Means |
|---|---|
| `APPROVED` | All required reviewers approved |
| `CHANGES_REQUESTED` | At least one reviewer requested changes — **you need to address them** |
| `REVIEW_REQUIRED` | No formal decision yet |
| `null` | No reviewers assigned or no review policy |

**Do not use `reviewDecision` to determine if a PR is waiting on the reviewer vs the author.** It is an aggregate and loses per-reviewer signal.

### `latestReviews[].state` (per-reviewer)

This is the correct signal for what action is needed:

| State | Action needed by |
|---|---|
| `CHANGES_REQUESTED` | **PR author** — reviewer wants changes addressed |
| `APPROVED` | Nobody — this reviewer is satisfied |
| `COMMENTED` | Ambiguous — reviewer left comments but no formal verdict; check if any comments are blocking |
| `DISMISSED` | Previous review was dismissed; treat as awaiting re-review |
| `PENDING` | Reviewer has a draft review not yet submitted |

### Categorizing your own PRs correctly

When listing your open merge requests, classify each one:

1. **Needs your action** — any reviewer has `CHANGES_REQUESTED`, or has `COMMENTED` and the comments contain unresolved threads
2. **Waiting on reviewer** — no reviews yet, or all reviews are `APPROVED` but merge is blocked for other reasons
3. **Merge conflict (DIRTY)** — `mergeStateStatus == "DIRTY"` — always surface first
4. **CI failing (UNSTABLE)** — `mergeStateStatus == "UNSTABLE"`
5. **Ready to merge (CLEAN + APPROVED)** — nothing blocking

A PR with `COMMENTED` reviews is **not** safely "waiting on reviewer" — the reviewer may have left actionable feedback without formally requesting changes. Always check.

## Fetching your open PRs with full review state

`gh pr list --author=@me` requires git repository context and errors without it. For cross-repo queries, use `gh search prs` — it works anywhere but lacks `mergeStateStatus` and `reviewDecision` in `--json` output (tracked in cli/cli#13239):

```bash
# Cross-repo: works outside a git directory, but no merge/review state
gh search prs --author=@me --state=open --json number,title,repository,url

# Per-repo: full state available
gh pr list --author=@me --state=open --repo <owner>/<repo> \
  --json number,title,mergeStateStatus,reviewDecision,latestReviews
```

When you need cross-repo results with review/merge state, use GraphQL:

```bash
gh api graphql -f query='{ viewer { pullRequests(first: 20, states: OPEN) { nodes {
  number title url
  repository { nameWithOwner }
  reviewDecision
  mergeStateStatus
  latestReviews(first: 10) { nodes { state author { login } } }
} } } }'
```

## Fetching review requests

Use GitHub search — matches what the UI shows. Do NOT filter results by `reviewDecision`:

```bash
gh api graphql -f query='{ search(query: "is:open is:pr review-requested:@me", type: ISSUE, first: 20) {
  nodes { ... on PullRequest {
    number title url
    repository { nameWithOwner }
    mergeStateStatus
    updatedAt
  } }
} }'
```

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
