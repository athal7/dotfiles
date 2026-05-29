---
name: review
description: Self-review your own diff before committing or pushing — multi-pass review of the changes you're about to ship.
license: MIT
compatibility: opencode
---

## Setup

Fetch the diff for your changes — staged, uncommitted, or a commit or branch you're about to push. Read modified files for full context; skip generated files, lock files, vendored code.

Read project rules: `AGENTS.md` (root + nested), `CONVENTIONS.md`, `REVIEW.md`, `CONTRIBUTING.md`, plus `docs/` development guides. `REVIEW.md` overrides everything else.

If the work is linked to an issue, fetch its acceptance criteria for the correctness pass.

## Local pass

Run these against the diff in order, treating each as a distinct lens. Write findings after each pass before moving to the next so you don't blur lenses.

**Always run:**

1. **Reviewability** — could a human understand and confidently approve this diff? Check for:
   - Unrelated changes (refactors, dep bumps, formatting fixes) mixed in → split into a separate commit
   - Whitespace-only or formatting-only hunks with no semantic content → drop or isolate
   - Large single commits that could decompose into logical steps without losing safety → suggest split points
   - Diff noise that obscures intent (indentation reflow, import reordering mixed with logic) → separate
   If any issues found, list the specific files/hunks and the recommended action (drop, stage separately, squash) before proceeding.
2. **Correctness** — does behavior match intent and, if linked, the issue's acceptance criteria? Check edge cases, error paths, and off-by-one boundaries.
3. **Code quality** — apply code-quality rules. Follow the pre-existing-pattern rule.

**Conditional (run if the diff touches the trigger):**

4. **Security** — when auth, params, sessions, encryption, CORS, env config, or dependencies appear. Trace input paths end-to-end.
5. **Performance** — when DB queries, associations, loops, batch jobs, view collections, or migrations appear. Check N+1, missing indexes, unbounded collections.

When in doubt, run the conditional pass.

After all passes: deduplicate findings, then verify each by attempting to disprove it (read surrounding code, check version-control history for pre-existing issues, confirm `file:line` is in the diff). Default is keep — discard only on positive disproof.

## QA when UI is touched

When the diff touches views, templates, frontend code, or UI interactions: spawn the project's dev server in the background (auto-detect from `package.json` scripts.dev/start, then `Procfile` web entry, then `Makefile` dev/serve/start target, then `README.md` getting-started block). Wait up to 15 s for the ready signal. Run QA verification on the changed flows. Kill the server when done. Include results under `## QA Results`.

## Apply findings

This is your own work — there's no audience to triage for. Apply every finding, then re-run the review. Iterate until the verdict is APPROVE; do not wait for input between iterations. Once APPROVE, proceed to commit.

See `output-format.md` for the output template.
