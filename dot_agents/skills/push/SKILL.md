---
name: push
description: Load before pushing — merge request description rules and the post-push CI and automated-review watch loop.
license: MIT
---
Load `commit` before preparing the push.


Show unpushed commits in chat first — branch name, one subject per line. The full test suite already ran at commit time; don't re-run it.

## Draft merge request

None exists → create one from the branch commits, as a draft. One exists → update title/body only on a material change (new scope, different fix, renamed component, changed API); skip for tests, docs, formatting. **Never flip draft↔ready.**

Description: 1-2 sentences. Skip headers, bullet lists, and anything obvious from the diff.

**Auto-close needs an explicit verb** — `Resolves`, `Fixes`, or `Closes` plus the identifier. A bare `#123` does not close anything.

**Never reference private issue keys in public repos.** Check repo visibility first; instead put the merge-request link on the issue.

```
Adds retry logic for flaky external API calls. Resolves #123
```

## Watch CI and automated review

Both are asynchronous; the push isn't settled until each has landed or been ruled out. Route GitHub reads through whatever GitHub pathway the harness provides.

- **Conflict with the base branch → resolve first.** A conflicted merge request can't run CI at all, draft or not.
- **No check runs on the current head** → nothing to wait for; the pre-push suite stands in. Don't treat absence as a problem.
- **Check runs pending** → sleep, re-check, repeat until resolved or a sane timeout. Failures → fix through the normal commit → push cycle.
- **Automated review** — same loop, matched against the *current* head, not a stale review. Timeout while still a draft → this repo doesn't review drafts; move on.
- **Review landed** → fetch its inline threads and top-level comments, fix actionable items, resolve each thread only after its fix is pushed. Reply (rather than resolve) to decline, defer, or add context — and only with approval.

## External contributions

Before contributing to any external project, check for `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, or equivalent. Follow their process — issue-first vs. PR-first, required templates, license requirements, DCO/sign-off, CI expectations. Never submit a PR to a project whose guidelines you haven't verified.
