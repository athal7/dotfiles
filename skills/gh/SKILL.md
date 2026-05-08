---
name: gh
description: GitHub CLI integration — non-obvious behavior for PRs, reviews, CI, and repo queries
license: MIT
compatibility: opencode
metadata:
  provides:
    - source-control
    - ci
    - automated-review
---

# Skill: gh

GitHub CLI (`gh`) gotchas that `--help` won't tell you.

## Reading PR/issue comments — prefer `gh pr view --json`

For plain comment reads, use `gh pr view N --json comments,reviews --jq ...` (or `gh issue view`) instead of `gh api repos/.../pulls/N/comments`. The `gh pr view` form is allow-listed as read-only; `gh api` is on `ask` because it accepts `-X POST/PATCH/DELETE`.

```bash
# Top-level PR comments
gh pr view "$PR" --json comments --jq '.comments[] | {user: .author.login, body: .body}'

# Inline review comments
gh pr view "$PR" --json reviews --jq '.reviews[] | {user: .author.login, state, body: .body}'
```

Field names differ from REST: `.author.login` (not `.user.login`), no `commit_id` or `in_reply_to_id`. Drop down to `gh api .../comments` only when you need those REST-only fields (e.g. the automated-review flow below).

## What needs action across repos

Bucket cross-repo PR work on `latestReviews[].state` and `mergeStateStatus`:

```bash
gh api graphql -f query='{
  viewer { pullRequests(first: 50, states: OPEN) { nodes {
    number title url isDraft mergeStateStatus
    repository { nameWithOwner }
    reviewRequests(first: 20) { nodes { requestedReviewer { ... on User { login } ... on Bot { login } } } }
    latestReviews(first: 20) { nodes { state author { login } submittedAt } }
    commits(last: 1) { nodes { commit { committedDate } } }
  } } }
  search(query: "is:pr is:open review-requested:@me", type: ISSUE, first: 50) { nodes { ... on PullRequest {
    number title url repository { nameWithOwner }
  } } }
}'
```

Bucket your authored PRs (closest-to-done first). `lastCommit = commits[-1].commit.committedDate`:

| Bucket | Rule |
|---|---|
| **conflict** | `mergeStateStatus == DIRTY` — fix first |
| **ci-failing** | `mergeStateStatus == UNSTABLE` |
| **review-to-address** | any `latestReviews[].state` in `(CHANGES_REQUESTED, COMMENTED)` with `submittedAt > lastCommit` — bots count |
| **ready-to-merge** | `mergeStateStatus == CLEAN` AND any `APPROVED` in `latestReviews[].state` AND no `CHANGES_REQUESTED`/`COMMENTED` newer than `lastCommit` |
| **waiting-for-review** | none of the above; `reviewRequests` non-empty or no review yet |

The `search` block returns others' PRs requesting your review (**review-requested**). For mentions and assigned issues without PRs, use `gh status` (`--org <org>` to scope, `-e <owner/repo>` to exclude).

### `mergeStateStatus` values

| Value | Means |
|---|---|
| `CLEAN` | No conflicts, branch protection satisfied |
| `DIRTY` | Merge conflicts |
| `UNSTABLE` | CI failing |
| `BLOCKED` | Branch protection unsatisfied (e.g. required approval missing) — **not a conflict** |
| `BEHIND` | Behind base branch |
| `HAS_HOOKS` | Mergeable with passing status and pre-receive hooks |
| `UNKNOWN` | Retry |

### Known silent failures

- `gh pr list --reviewer @me` returns empty even when review requests exist — use the GraphQL `search` block above (or `gh search prs --review-requested=@me`).
- `gh search prs --reviewed-by @me` returns empty — for PRs you've reviewed, query per-repo with `gh pr list --json author,reviews` and filter `reviews[].author.login == @me AND author.login != @me`.

## Automated review (Copilot, Codex, etc.)

`gh` is the transport for GitHub-hosted automated reviewers. Per-org config lives in `~/.local/share/chezmoi/.chezmoidata/local.yaml` under `orgs.<org>.automated_review` (see `local.yaml.example` in the dotfiles repo root for schema). Orgs without that block have no automated review available.

### Is automated review available for this repo?

**Run this exact command. Do not infer availability from collaborator lists, repo settings, prior PRs, or anything else.**

```bash
ORG=$(gh repo view --json owner -q '.owner.login')
chezmoi data --format json | jq -r ".orgs[\"$ORG\"].automated_review // empty"
```

- **Non-empty output** = available. The returned object has `bot_login`, `auto_runs`, and `trigger`. Proceed with the trigger/wait/fetch flow below.
- **Empty output** = not configured for this org. Only then fall back to the no-automation pipeline.

Common wrong checks that will give you a false negative:
- Listing repo collaborators and looking for the bot login — the bot is not added as a collaborator
- Checking org-level installed apps via `gh api` — the bot may be installed at GitHub-account level rather than per-org
- Looking at prior PRs for bot reviews — a repo with no prior bot reviews may still be configured

### Fetch the latest automated review for a PR

Pull all reviews authored by the configured `bot_login`. Most recent first; take `[0]` for the latest:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" --paginate \
  --jq "[.[] | select(.user.login == \"$BOT_LOGIN\")] | sort_by(.submitted_at) | reverse"
```

Each review has `commit_id` (the head SHA at review time — needed for staleness checks) and `submitted_at`. Inline comments live separately:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR/comments" --paginate \
  --jq "[.[] | select(.user.login == \"$BOT_LOGIN\") | {path, line, body, id, in_reply_to_id, commit_id}]"
```

Reply threads on a comment use `in_reply_to_id` chains.

### Trigger automated review

**Use only the commands below. Do not invent alternatives.** The REST endpoint `POST /repos/{o}/{r}/pulls/{n}/requested_reviewers` returns 422 *"Reviews may only be requested from collaborators"* when given `copilot-pull-request-reviewer` — the bot is not a collaborator. Only `gh pr edit --add-reviewer "@copilot"` works, because `@copilot` is a special handle that `gh` resolves client-side (see `gh pr edit --help`).

The `trigger` field returned by the availability check tells you which form. Parse it and run the corresponding command — do not hardcode the handle or text:

- `add_reviewer @handle` → `gh pr edit $PR --add-reviewer "@handle"`
- `comment @handle <text>` → `gh pr comment $PR --body "@handle <text>"`

```bash
TRIGGER=$(chezmoi data --format json | jq -r ".orgs[\"$ORG\"].automated_review.trigger")
FORM="${TRIGGER%% *}"          # "add_reviewer" or "comment"
ARGS="${TRIGGER#* }"           # everything after the first word

if [[ "$FORM" == "add_reviewer" ]]; then
  gh pr edit "$PR" --add-reviewer "$ARGS"
else
  gh pr comment "$PR" --body "$ARGS"
fi
```

Triggering is a public action — it appears in the timeline. Announce it before doing it.

After triggering, verify the bot was actually added as a reviewer before waiting:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR/requested_reviewers" --jq '.users[].login, (.users[] | select(.type=="Bot") | .login)'
```

Note: Copilot appears in `requested_reviewers` as login `Copilot` (a Bot user, app slug `copilot-pull-request-reviewer`), but its review submissions use login `copilot-pull-request-reviewer[bot]` — the `bot_login` from the availability check matches the *review author*, not the requested-reviewer login.

### Wait for a fresh review

After triggering (or to wait for an auto-running bot), poll until a review exists with a `commit_id` matching the current HEAD (or just newer than `since_sha`). Reasonable cadence: every 5s, timeout 120s.

```bash
TARGET_SHA=$(gh pr view "$PR" --json headRefOid -q .headRefOid)
for i in {1..24}; do
  LATEST=$(gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" --paginate \
    --jq "[.[] | select(.user.login == \"$BOT_LOGIN\")] | sort_by(.submitted_at) | reverse | .[0].commit_id")
  [[ "$LATEST" == "$TARGET_SHA" ]] && break
  sleep 5
done
```

### Was a prior review already requested-and-dismissed?

Don't re-trigger if the human author dismissed the bot without a fix and the diff hasn't materially changed. Check review timeline events:

```bash
gh api "repos/$OWNER/$REPO/pulls/$PR/reviews" --paginate \
  --jq "[.[] | select(.user.login == \"$BOT_LOGIN\") | {state, dismissed: .state == \"DISMISSED\", submitted_at, commit_id}]"
```

`state == "DISMISSED"` with no follow-up review means the author chose not to act on it.

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
