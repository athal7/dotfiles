---
description: Review changes [commit|branch|pr], defaults to uncommitted
---

Review code changes. Load the `review-checklist` skill.

**Input:** $ARGUMENTS

Based on input:
- **No arguments**: `git diff` + `git diff --cached` + `git status --short`, then `git diff origin/<default>...HEAD`
- **Commit hash**: `git show $ARGUMENTS`
- **Branch name**: `git diff $ARGUMENTS...HEAD`
- **PR URL/number**: `gh pr view`, `gh pr diff`. Use `gh-pr-inline` skill for posting inline comments.
