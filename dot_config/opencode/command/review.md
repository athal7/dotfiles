---
description: Review changes [commit|branch|pr|staged], defaults to uncommitted
---

Review code changes. Load the `review-checklist` skill.

**Input:** $ARGUMENTS

Based on input:
- **No arguments**: `git diff` + `git diff --cached` + `git status --short`, then `git diff origin/<default>...HEAD`
- **`staged`** (or **`pre-commit`**): Review only staged changes (`git diff --cached`). This is the pre-commit gate — report blockers that should prevent the commit. Be strict on security, correctness, and behavior changes. Be lenient on style nits.
- **Commit hash**: `git show $ARGUMENTS`
- **Branch name**: `git diff $ARGUMENTS...HEAD`
- **PR URL/number**: `gh pr view`, `gh pr diff`. Also fetch prior review history (see below). Use `gh-pr-inline` skill for posting inline comments.

**For PR reviews, also fetch prior review history before loading the skill:**
- `gh pr reviews $PR --json author,state,body` — list all submitted reviews (APPROVED, CHANGES_REQUESTED, COMMENTED)
- `gh api repos/{owner}/{repo}/pulls/$PR_NUMBER/comments` — inline review comments with `path`, `line`, `body`, `in_reply_to_id`
- `gh api repos/{owner}/{repo}/issues/$PR_NUMBER/comments` — general PR comments

Pass this prior review history to the `review-checklist` skill so it can avoid re-raising already-addressed issues and flag any that remain unresolved.

If the diff modifies views, templates, Turbo streams, or frontend code, suggest running `/qa` for browser-based verification after the review.
