---
name: push
description: Push approval protocol, branch naming, merge request descriptions, and post-push CI watching
license: MIT
metadata:
  provides:
    - push
  requires:
    - commit
    - source-control
    - branching
    - issues
    - ci
---

**Never push on your own initiative.** A push requires either an explicit user command ("push", "ship it", "commit and push") or explicit approval after you show a push summary.

## Before pushing

1. **Check the branch name** via your `branching` capability. Rename auto-generated worktree branches (e.g., `opencode/cosmic-wizard`) to `<type>/<short-description>` matching the commit type, 2-4 kebab-case words.
2. **Run the full local test suite.** If tests fail: fix them first, or stop and report on a user-initiated push.
3. **Show a summary of unpushed commits** via your `branching` capability.

If the user issued a push command, push immediately — the command is the approval.

If you decided a push is needed, **end your response and wait.** Only push on explicit confirmation in the next message: "yes", "approve", "go ahead", "lgtm", "do it". General continuations like "keep going" and earlier-in-conversation approvals do NOT count.

## After push — draft merge request

Create or update a draft merge request via your `source-control` capability. If none exists, create one from the branch commits. If one exists, update title/body only when the change is material (new feature scope, different fix, renamed component, changed API) — skip minor additions like tests/docs/formatting. Never change draft↔ready state.

**Description format:** 1-2 sentence summary, only add detail if non-obvious. Link the issue when the tracker is visible to the repo's audience (e.g., `Closes #123`). Skip headers, bullet lists, and implementation details obvious from the diff. **Never reference internal/private issue keys in public repos** — instead, update the issue with a link to the merge request via your `issues` capability. Check repo visibility via your `source-control` capability.

Example:
```
Adds retry logic for flaky external API calls. Closes #123
```

## After draft merge request — watch CI

Watch CI to completion via your `ci` capability. Do not hand back to the user before this finishes.

1. Poll every 30s until checks are no longer queued or in progress.
2. On all-pass, report success with a markdown link to the merge request — never the bare number.
3. On failure: get the failure output, fix the root cause, run the full test suite locally before pushing the fix, then commit (via `commit`) and push. Return to step 1.

Keep iterating until CI is green. Do not give up after one fix attempt.
