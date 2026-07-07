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

A push kicks off two asynchronous signals: CI, and — where the repo has it — an automated code review on the merge request. The push isn't settled until both have landed or been confirmed not applicable to a draft.

- **CI.** First rule out a merge conflict with the base branch: a conflicted merge request can't run CI at all, regardless of draft state, so a conflict has to be resolved before anything else — same commit → push cycle as any other fix. Only once there's no conflict does the rest apply: dispatch the `github` subagent (`task` tool, `subagent_type: github`) to check whether any check run has started for the current head. If none appear, there's nothing to wait for — the pre-push local full test suite already stands in for it; don't block on CI and don't treat its absence as a problem. If check runs do appear but haven't finished, sleep briefly, then re-dispatch it to check again — repeat until CI resolves or a sane timeout passes. Fix failures through the normal commit → push cycle and re-check.
- **Automated code review.** When the repo has automated code review configured, dispatch the `github` subagent (`task` tool, `subagent_type: github`) to check for a review matching the current head — not a stale one. If none has landed yet, sleep briefly, then re-dispatch it to check again — repeat until a review lands or a sane timeout passes. If that timeout is reached while the merge request is still a draft, treat it the same way as CI: this repo's automated review doesn't run on drafts, nothing to wait for, move on. If a review does land, dispatch it to fetch the findings it posted as inline threads and top-level comments — triage them, fix actionable items through the normal commit → push cycle, and once a fix has landed, dispatch the `github` subagent to resolve the addressed threads; reply only when declining, deferring, or questioning, and get approval before dispatching the `github` subagent to post any reply. If the repo has no automated code review configured at all, there is nothing to wait for on that signal either.
