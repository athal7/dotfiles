---
name: push
description: Load before pushing — merge request description rules and the post-push CI and automated-review watch loop.
license: MIT
---

Load `commit` before preparing the push.

Show unpushed commits in chat first.
State the branch name and one subject per line.
Do not re-run the full suite during push unless a push-time check fails and needs a fix.

## Merge request policy

Use native `github` operations for repository, issue, PR, search, checkout, push, and Actions-watch work.
Use approval-gated `gh api` only when native GitHub support does not cover the operation.
Show the full payload and ask `Do you approve?` before every remote write.

No existing request means create one from the branch commits.
A material scope change means update the title or body.
Tests, docs, and formatting do not require a title or body update.
Never flip draft or ready state during a push.
A deliberate draft change belongs in the `merge-request` workflow.

Write the description in 1 or 2 sentences.
Do not add headers or obvious bullet lists.
Use `Resolves`, `Fixes`, or `Closes` for auto-close.
A bare issue reference does not close anything.
Never reference private issue keys in public repositories.
Put the merge-request link on the private issue instead.

Example:

```text
Adds retry logic for flaky external API calls. Resolves #123
```

## Watch loop

A push is not settled until CI and automated review have landed or been ruled out.
Use `github.run_watch` for GitHub Actions.
Use native GitHub reads for check status, comments, and review threads.

- Resolve base-branch conflicts before waiting for CI.
- If no check runs exist on the current head, treat the pre-push suite as the gate.
- If checks are pending, wait and re-check until they resolve or time out.
- If checks fail, fix through the normal commit and push cycle.
- Match automated review against the current head.
- If review lands, fetch inline threads and top-level comments.
- Fix actionable review items.
- Resolve a thread only after its fix is pushed.
- Reply to decline, defer, or add context only after approval.

## External contributions

Before contributing to an external project, check `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, or equivalent.
Follow the project process.
Do not submit a request before you verify the guidelines.
