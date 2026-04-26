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
---

Fetch the diff based on input:

- **No arguments**: `git diff` + `git diff --cached` + `git status --short`, then `git diff origin/<default>...HEAD`
- **`staged`** (or **`pre-commit`**): `git diff --cached` only
- **Commit hash**: `git show <hash>`
- **Branch name**: `git diff <branch>...HEAD`
- **Code review request URL/number**: use your `source-control` capability to fetch the diff and metadata; check out the branch locally (save and restore the original branch)

Read the modified files for full context. Skip generated files, lock files, vendored code.

Read project rules: `AGENTS.md` (root + nested), `CONVENTIONS.md`, `REVIEW.md`, `CONTRIBUTING.md`, plus `docs/` development guides. `REVIEW.md` overrides everything else.

Fetch issue context via your `issues` capability — parse branch name and code review request body for issue IDs, fetch acceptance criteria.

---

## Pick a pipeline

| Whose code | Code review request exists | Automated review | Pipeline |
|---|---|---|---|
| Mine | No | — | **A. Local specialists** |
| Mine | Yes | Available + has run | **B. Self-review over automation** |
| Mine | Yes | Available, not yet run | Trigger via `automated-review`, wait, then **B** |
| Mine | Yes | Not available | **A** |
| Theirs | Yes | Available + has run | **C. Reviewer over automation** |
| Theirs | Yes | Available, not yet run | Announce, trigger via `automated-review`, wait, then **C** |
| Theirs | Yes | Not available | **D. Read the diff in this session, post your own judgments.** |

Check availability and fetch any prior review via your `automated-review` capability.

---

## A. Local review

Review the diff yourself in this session. The diff, modified files, and project rules are already loaded.

Run these passes against the diff in order, treating each as a distinct lens. After each, write a short list of findings before moving on so you don't blur the lenses together.

**Always run:**

1. **Correctness** — logic errors, missing edge cases, off-by-one, wrong API signatures, callback/event/job side effects, error handling. Trace data flow across files.
2. **Completeness** — column/enum/scope/method renames or removals propagated everywhere; fixtures, tests, views, serializers, callers, docs all updated; new code paths covered by tests.
3. **Maintainability** — naming, duplication, dead code, test validity, comprehensibility for the next reader.

**Conditional (run if the diff touches the trigger):**

4. **Conventions** — when ORM persistence methods, caching, or new data models/columns appear. Check project rules.
5. **Security** — when auth, params, cookies/sessions, encryption, CORS, env config, or dependencies appear. Trace input paths end-to-end.
6. **Performance** — when DB queries, associations, loops, batch jobs, views rendering collections, or migrations appear. Check N+1, missing indexes, unbounded collections.

When in doubt, run the conditional pass.

For deeper per-pass guidance and the verification protocol, see `~/.agents/skills/review/specialists/` and `~/.agents/skills/review/verify-findings.md` — but only consult them if you're stuck on what a pass should cover, not as a routine step.

After all passes: deduplicate findings, verify each by attempting to disprove it (read the surrounding code; check `git blame` for pre-existing issues; confirm `file:line` is in the diff). Default is keep — discard only on positive disproof.

---

## B. Self-review over automation (your code, automation has reviewed)

Reconcile the prior review against current state. Apply this protocol to **both** the automated review (via `automated-review`) **and** any human reviews already on the code review request (via `source-control`):

1. Fetch the prior review (`commit_id` / submitted_at, inline comments with `path/line/body` and reply thread relationships).
2. **Staleness judgment**: read `git diff <commit_id>..HEAD`. Subjective call: is the delta substantial enough that a fresh review is warranted? New logic surfaces, structural refactors, new files/dependencies → stale. Typo fixes, comments, formatting → not stale.
3. **Per-finding status**: for each prior comment, read the diff slice around `file:line` and any reply thread. Classify as `addressed | dismissed-with-reasoning | pending | moved-but-still-true`.
4. If automated review is stale → re-trigger via `automated-review`, wait, restart from step 1. (Do not re-trigger if previously dismissed without action and the diff has not materially changed.)
5. **Pending or moved-but-still-true findings → fix them via TDD.**

Then run the always-on layer (below).

---

## C. Reviewer over automation (their code, automation has reviewed)

Same reconciliation as B (steps 1–4 above), applied to both automated and prior human reviews.

Then read the diff in this session and form your own judgments. Posting AI findings as your own is dishonest when an embedded reviewer is already on the code review request — your contribution here is reviewer judgment, not a duplicate AI pass.

What you contribute:
- Agreement, disagreement, or expansion on bot findings (post as inline replies on those threads, not new comments)
- Issues the bot missed that you genuinely caught yourself
- `moved-but-still-true` cases — the bot's original comment is gone but the concern remains; surface explicitly
- Reviewer judgment: verdict, AC coverage, QA observations

Then run the always-on layer (below).

---

## Always-on layer (every pipeline)

**Acceptance criteria check**: if issue context was found, evaluate each AC against the diff. If no linked issue, note "No linked issue with acceptance criteria found."

**Conditional QA**: if the diff modifies views, templates, controllers, frontend code, or UI interactions:

1. Auto-detect the dev server command in this priority order:
   - `package.json` → `scripts.dev`, then `scripts.start`
   - `Procfile` → the `web:` entry
   - `Makefile` → a `dev`, `serve`, or `start` target
   - `README.md` → "Getting started" / "Running locally" code block
2. Spawn in the background. Wait up to 15 s for "listening on" / "ready" / port-bound log line.
3. Use your `qa` capability with the changed flows and local URL.
4. Kill the server when done. Restore the original branch.
5. Include results under `## QA Results` in the output.

For code review requests, always attempt server start. For commit/branch/staged reviews, only if UI is touched. If no command found, note "QA skipped — could not detect dev server command."

---

## Submit and output

Read `~/.agents/skills/review/output-format.md` for the output template.

**Inline-first when posting**: post findings as inline comments via your `source-control` capability. Do not include verdict, TL;DR, or summaries in the submitted body — those are session output only. Exception: a review-wide observation that genuinely cannot be attributed to any line.

**Show the full proposed review and ask "Do you approve?"** before submitting to a code review request. Then STOP and wait for explicit approval.

When a code review request has reviews and merge conflicts, use merge (not rebase) to resolve — rebasing invalidates existing inline comments.
