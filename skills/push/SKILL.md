---
name: push
description: Push approval protocol, branch naming, merge request descriptions, and post-push CI watching
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

## After draft merge request — watch CI and request review

Kick off both in parallel — they are independent async waits:

1. **Watch CI** to completion. Fix failures through the normal commit → push cycle and re-check.
2. **Request automated review** (e.g., GitHub Copilot) unless a human has already reviewed or is actively reviewing — automated review adds noise after human judgment.
