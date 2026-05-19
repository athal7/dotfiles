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

## After draft merge request — trigger automated review and watch CI in parallel

If automated review is available for this repo, trigger it *in parallel* with watching CI. Iterate on the combined feedback from both — don't wait for one before responding to the other.

Watch CI to completion. Do not hand back to the user before both CI and automated review have completed.

1. Trigger automated review (if configured) and start polling CI every 30s in parallel.
2. As findings arrive from automated review, address them. As CI failures arrive, fix the root cause.
3. Both fixes flow through `commit` then `push`, returning to step 1 of this iteration loop.
4. On all-pass from CI *and* either no automated review or all findings addressed, report success with a markdown link to the merge request — never the bare number.

Keep iterating until both CI is green and automated review feedback is resolved. Do not give up after one fix attempt.
