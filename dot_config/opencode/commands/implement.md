---
description: implement a change [issue|description], plan/build/review/ship
---

Workflow: implement.

## Workspace setup

Check the repo's AGENTS.md for branch conventions. If the repo uses feature branches and you're on `main`: load the `opencode` skill and use dispatch.md to create a worktree session for this work — the implementation should happen in an isolated worktree, not on main. If the repo commits directly to main (e.g., dotfiles), skip this step.

## Plan

Gather context before proposing anything:
- Read relevant source files, specs, git history
- If the user references an issue/PR/ticket, fetch it
- For design decisions or tradeoffs, load `architecture` or `thinking-tools` skill
- For multi-step work, use TodoWrite to track phases

Present the plan: what files change, what tests, what risks. **Wait for approval before proceeding.**

## Build

Dispatch to build with a focused prompt. Build follows strict TDD (red/green/refactor) — that's in its prompt. Present the changeset when build returns. **Wait for approval before proceeding.**

## Review

Run these passes against the diff in order. Write findings after each pass before moving to the next.

**Always run:**
1. **Reviewability** — can a human reviewer understand this diff? Unrelated changes mixed in, whitespace noise, large commits that should be split.
2. **Correctness** — does behavior match intent? Edge cases, nil safety, error handling, validation bypass.
3. **Code quality** — naming, duplication, complexity, pre-existing patterns followed.

**Conditional (run if the diff touches the trigger):**
4. **Security** — when auth, params, sessions, encryption, CORS, env config, or dependencies appear.
5. **Performance** — when DB queries, associations, loops, batch jobs, or migrations appear.

After all passes: deduplicate findings, verify each by attempting to disprove it (read surrounding code, check git history for pre-existing issues, confirm the finding is in the diff). Discard only on positive disproof.

If the diff touches UI (views, templates, CSS, frontend code): run QA verification with the browser.

**Present the review for approval before proceeding.**

## Ship

Load `commit` skill for staging, test verification, and commit message format. Then load `push` skill for branch naming, merge request creation, and CI watching. All remote actions require explicit approval.

$ARGUMENTS
