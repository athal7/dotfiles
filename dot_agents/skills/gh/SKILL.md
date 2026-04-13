---
name: gh
description: GitHub CLI integration — non-obvious behavior for PRs, reviews, CI, and repo queries
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - code-review
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

`gh pr list --author=@me` silently returns nothing outside a repo. Use GraphQL instead:

```bash
gh api graphql -f query='{ viewer { pullRequests(first: 20, states: OPEN) { nodes {
  number title url
  repository { nameWithOwner }
  reviewDecision
  mergeStateStatus
  latestReviews(first: 10) { nodes { state author { login } } }
} } } }'
```

Follow up with per-repo `gh pr list` for accurate `mergeStateStatus` — GraphQL often returns `UNKNOWN`:

```bash
gh pr list --author=@me --state=open --repo <owner>/<repo> \
  --json number,title,mergeStateStatus,reviewDecision,latestReviews
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
