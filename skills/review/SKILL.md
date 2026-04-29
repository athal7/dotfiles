---
name: review
description: Review changes [commit|branch|merge-request|staged] — verifies your own work before shipping, or reviews someone else's code with inline comments and approval
license: MIT
compatibility: opencode
metadata:
  provides:
    - verify
    - code-review
  requires:
    - qa
    - source-control
    - automated-review
    - issues
    - code-quality
---

## Setup

Fetch the diff for the requested scope (commit hash, branch, staged, or code review request via your `source-control` capability). Read modified files for full context; skip generated files, lock files, vendored code.

Read project rules: `AGENTS.md` (root + nested), `CONVENTIONS.md`, `REVIEW.md`, `CONTRIBUTING.md`, plus `docs/` development guides. `REVIEW.md` overrides everything else.

Fetch issue context via your `issues` capability — parse branch name and code review request body for issue IDs, fetch acceptance criteria.

Check whether automated review (e.g. embedded AI reviewer) is available and has run via your `automated-review` capability. If available but not yet run, trigger it and wait before proceeding.

## Two paths

### Reviewing your code (no code-review-request, OR your own merge request)

1. **If automation has reviewed**, reconcile first: fetch prior comments and per-finding classify as `addressed | dismissed-with-reasoning | pending | moved-but-still-true`. Pending and moved-but-still-true findings → fix via TDD before proceeding.
2. **Run the local pass** (below).

### Reviewing theirs (someone else's code review request)

Your contribution is reviewer judgment, not a duplicate AI pass. **Posting AI-generated findings as your own is dishonest** when an embedded automated reviewer is already on the request.

1. **If automation has reviewed**, reconcile first as above. Add inline replies that agree, disagree, or expand on bot findings — don't open new threads duplicating them.
2. **Run the local pass** (below) but only post issues genuinely caught yourself, plus `moved-but-still-true` cases where the bot's original comment is gone but the concern remains.
3. **Add reviewer judgment**: verdict, acceptance-criteria coverage, QA observations.

## Local pass

Run these against the diff in order, treating each as a distinct lens. Write findings after each pass before moving to the next so you don't blur lenses.

**Always run:**

1. **Correctness** — does behavior match intent and the issue's acceptance criteria? See `specialists/correctness.md`.
2. **Code quality** — apply your `code-quality` capability. Follow the pre-existing-pattern rule.

**Conditional (run if the diff touches the trigger):**

3. **Security** — when auth, params, sessions, encryption, CORS, env config, or dependencies appear. Trace input paths end-to-end.
4. **Performance** — when DB queries, associations, loops, batch jobs, view collections, or migrations appear. Check N+1, missing indexes, unbounded collections.

When in doubt, run the conditional pass. For deeper guidance, see `specialists/` and `verify-findings.md`.

After all passes: deduplicate findings, verify each by attempting to disprove it (read surrounding code, check version-control history for pre-existing issues, confirm `file:line` is in the diff). Default is keep — discard only on positive disproof.

## QA when UI is touched

If the diff modifies views, templates, controllers, frontend code, or UI interactions: spawn the project's dev server in the background (auto-detect from `package.json` scripts.dev/start, then `Procfile` web entry, then `Makefile` dev/serve/start target, then `README.md` getting-started block). Wait up to 15 s for ready signal. Use your `qa` capability with the changed flows. Kill the server when done.

Always attempt for code review requests; only when UI is touched for commit/branch/staged. Include results under `## QA Results`.

## Submit

Post findings as inline comments via your `source-control` capability — do not include verdict, TL;DR, or summaries in the submitted body (those are session output only). Exception: a review-wide observation that genuinely cannot be attributed to any line.

**Show the full proposed review and ask "Do you approve?"** before submitting. STOP and wait for explicit approval.

When a code review request has reviews and merge conflicts, use merge (not rebase) — rebasing invalidates existing inline comments.

See `output-format.md` for the output template.
