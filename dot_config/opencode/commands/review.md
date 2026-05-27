---
description: review changes [commit|branch|pr|staged], defaults to uncommitted
subtask: true
---

Workflow: code-review. You are reviewing someone else's code.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Setup — fetch diff, read modified files and project rules
- Automated review reconciliation — classify bot findings if present
- Local pass — run review passes (reviewability, correctness, quality, +conditional)
- QA — browser verification if diff touches UI
- Submit — present findings for approval, post inline comments

## Setup

Fetch the diff for the target: $ARGUMENTS. If empty, review uncommitted changes. If it looks like a PR number/URL, branch name, or commit SHA, route accordingly.

Read modified files for full context; skip generated files, lock files, vendored code. Read project rules: `AGENTS.md`, `CONVENTIONS.md`, `REVIEW.md`, `CONTRIBUTING.md`. Fetch issue context from branch name or merge request body.

## Automated review reconciliation

If automated review (e.g., GitHub Copilot) has run (check for bot comments): classify each finding as `addressed | dismissed-with-reasoning | pending | moved-but-still-true`. Treat pending and moved-but-still-true as required input.

Your contribution is reviewer judgment, not a duplicate AI pass. **Posting AI-generated findings as your own is dishonest** when an automated reviewer is already on the request. Only post issues genuinely caught yourself, plus moved-but-still-true cases.

## Local pass

Run these against the diff in order. Write findings after each pass before moving to the next.

**Always run:**
1. **Reviewability** — can a human reviewer understand and approve this diff? Unrelated changes, whitespace noise, large commits that should be split.
2. **Correctness** — does behavior match intent and acceptance criteria? Edge cases, nil safety, error handling.
3. **Code quality** — naming, duplication, complexity, pre-existing patterns.

**Conditional:**
4. **Security** — when auth, params, sessions, encryption, CORS, or dependencies appear.
5. **Performance** — when DB queries, associations, loops, batch jobs, or migrations appear.

After all passes: deduplicate findings, verify each by attempting to disprove it. Discard only on positive disproof.

## QA

If the diff touches UI: run QA verification with the browser. Always attempt for merge requests; only when UI is touched for commits.

## Submit

Present findings for approval. All remote writes (posting comments, submitting review) require explicit approval.

Post findings as inline comments — no verdict or summary in the submitted body. When the merge request has reviews and merge conflicts, use merge (not rebase) — rebasing invalidates existing inline comments.
