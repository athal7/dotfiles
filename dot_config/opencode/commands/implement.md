---
description: implement a change [issue|description], plan/build/review/ship
---

Workflow: implement.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Workspace setup — branch/worktree if needed per repo conventions
- Plan — gather context, dispatch plan agent, create proposal, present for approval
- Build — implement tasks via openspec-apply-change, present changeset for approval
- Review — run review passes against diff, route findings, present for approval
- Ship — commit, push, watch CI

## Workspace setup

Check the repo's AGENTS.md for branch conventions. If the repo uses feature branches and you're on `main`: load the `opencode` skill and use dispatch.md to create a worktree session for this work — the implementation should happen in an isolated worktree, not on main. If the repo commits directly to main (e.g., dotfiles), skip this step.

## Plan

Gather context, then dispatch the plan agent for analysis:

1. Read relevant source files and git history
2. If the user references an issue/PR/ticket, fetch it
3. Check `openspec/specs/` for requirements that constrain this change
4. Dispatch plan agent with: the user's request, gathered context, relevant spec constraints, and the question "what should change and why?"
5. Plan agent returns a structured recommendation with reasoning and tradeoffs

Create an OpenSpec proposal to persist the plan: dispatch build with `openspec-propose` to create proposal + design + tasks. The proposal is the plan artifact — it captures what changes, why, and the task breakdown.

**Present the proposal for approval. Wait before proceeding.**

## Build

Load `openspec-apply-change` and work through the tasks. For each task, dispatch build with strict TDD scope. Track progress via task checkboxes.

**Present the changeset for approval. Wait before proceeding.**

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

**Route findings:**
- **Build-level** (bug, style, missing test) → dispatch build for a targeted fix, then re-review the fix
- **Plan-level** (wrong approach, missing requirement) → re-dispatch plan agent, update the proposal
- **Human judgment** (tradeoff, scope question) → present to the user and wait

**Present the review for approval before proceeding.**

## Ship

Load `commit` skill for staging, test verification, and commit message format. Then load `push` skill for branch naming, merge request creation, and CI watching. All remote actions require explicit approval.

**CI failure → diagnose and route:** code fix → dispatch build. Approach problem → re-dispatch plan. Flaky test → re-run. Do not treat CI failure as terminal.

$ARGUMENTS
