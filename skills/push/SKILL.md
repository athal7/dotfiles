---
name: push
description: Push approval protocol, branch naming, merge request descriptions, and post-push CI and code-review watching
license: MIT
---

## Before pushing

1. **Check the branch name.** Rename auto-generated worktree branches (e.g., `opencode/cosmic-wizard`) to `<type>/<short-description>` matching the commit type, 2-4 kebab-case words.
2. **Run the full local test suite.** Fix failures before pushing.
3. **Show a summary of unpushed commits in chat** — branch name, commit subjects, one per line.

## After push — draft merge request

Create or update a draft merge request. If none exists, create one from the branch commits. If one exists, update title/body only when the change is material (new feature scope, different fix, renamed component, changed API) — skip minor additions like tests/docs/formatting. Never change draft↔ready state.

**Description format:** 1-2 sentence summary, only add detail if non-obvious. Link the issue when the tracker is visible to the repo's audience (e.g., `Closes #123`). Skip headers, bullet lists, and implementation details obvious from the diff. **Never reference internal/private issue keys in public repos** — instead, update the issue with a link to the merge request. Check repo visibility before linking.

Example:
```
Adds retry logic for flaky external API calls. Closes #123
```

## After draft merge request — watch CI and code review

A push kicks off two asynchronous signals: CI, and — where the repo has it — an automated code review on the merge request. The push isn't settled until both have landed.

- **CI.** Watch CI to completion. Fix failures through the normal commit → push cycle and re-check.
- **Automated code review.** When the repo has automated code review configured, wait for its review to land on the just-pushed change — the review must match the current head, not a stale one. Triage the findings it posts as inline threads and top-level comments. Fix actionable items through the normal commit → push cycle and resolve the addressed threads; reply only when you are declining, deferring, or questioning, and get approval before posting any reply. If the repo has no automated code review configured, there is nothing to wait for on that signal.
