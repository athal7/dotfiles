---
name: review
description: Review changes [commit|branch|pr|staged], defaults to uncommitted
---

Load the `review-checklist` skill and follow its instructions.

Fetch the diff based on input:
- **No arguments**: `git diff` + `git diff --cached` + `git status --short`, then `git diff origin/<default>...HEAD`
- **`staged`** (or **`pre-commit`**): `git diff --cached` only
- **Commit hash**: `git show <hash>`
- **Branch name**: `git diff <branch>...HEAD`
- **PR URL/number**: `gh pr view`, `gh pr diff`

Pass the input type and diff to the skill — it handles everything else (PR history, context, QA, output).
