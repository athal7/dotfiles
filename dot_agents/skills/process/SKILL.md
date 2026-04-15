---
name: process
description: Development workflow orchestrator for non-trivial implementation tasks — enforces plan → expert review → user approval → implement → verify → commit phase graph with delegation, checkpoint gates, and session context logging
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  requires:
    - issues
    - architecture
    - tdd
    - commit
    - push
    - verify
    - branching
    - meetings
    - logs
    - agent
---

## Overview

You are the orchestrator for this session. Your job is to enforce the phase graph and delegate implementation work to subagents. You do not implement directly — you plan, review, delegate, and verify.

**Research before asking.** Explore the codebase, read files, check git history, use your `issues`, `meetings`, or `logs` capability as needed. Only ask the user when information isn't discoverable.

**Issue tracking.** Find or create an issue before starting. Search first using your `issues` capability; create only if no suitable issue exists. Set it to In Progress and assign it to the user before writing any code. Link work to the issue (branch name, merge request description, commit message). Do NOT transition the issue to In Review — that is automated.

**Scope discipline.** Only change what was asked. Do not refactor adjacent code, update unrelated deps, or add unrequested features. Note out-of-scope findings but do not act on them.

**Worktree branch conflicts.** If the target branch is already checked out in another worktree, do NOT use that worktree. Instead: (1) remove it (`git worktree remove <path> --force`), then (2) check out the branch in the current worktree.

Set up todos immediately:

```
[ ] Phase 1: Plan
[ ] Phase 2: Expert review
[ ] Phase 3: User approval → implement
[ ] Phase 4: Implement (via task tool)
[ ] Phase 5: Verify
[ ] Phase 6: Learn
[ ] Phase 7: User approval → commit
[ ] Phase 8: Commit
```

---

## Phase 1: Plan

Create a written plan before any implementation. The plan must include:

1. What files will change and why
2. The approach and key decisions
3. Risks or open questions

Use your `architecture` capability before writing the plan:

- For **architecture decisions** (multiple valid approaches, hard to reverse, crosses system boundaries): use Section 1 to evaluate options with the expert agent.
- For **all changes** that touch domain logic, authorization, state machines, or anything enforced in more than one layer: follow Section 3 (Design Prerequisite Check). Answer every question by reading the relevant code. Surface any prerequisite refactors before planning the feature.

**Gate:** Do not proceed until the plan is written.

---

## Phase 2: Expert Review

Spawn the `expert` agent to review the plan:

```
Task("Review this implementation plan and tell me if it's sound. Point out risks, missing edge cases, or better approaches.", subagent_type="expert")
```

Address any blockers the expert raises.

**Gate:** Do not proceed until the expert has reviewed and blockers are addressed.

---

## Phase 3: User Approval → Implement

Present the final plan to the user and STOP. Wait for explicit approval before implementing.

**Gate:** Wait for a clear "yes", "approved", "lgtm", or equivalent.

---

## Phase 4: Implement

**Never implement directly.** Spawn a `general` subagent for each implementation unit:

```
    Task("Implement <specific task>. Use your `tdd` capability and follow its red/green/refactor loop. <relevant context>", subagent_type="general")
```

Key rules for implementation tasks:
- Each task prompt must include the TDD instruction
- Scope each task tightly — one logical change per subagent
- Wait for each task to complete before spawning the next if they are dependent
- Independent tasks can be spawned in parallel

**Gate:** All implementation tasks complete before proceeding.

---

## Phase 5: Verify

After implementation, run all of the following. Fix any failures before proceeding.

1. **Tests** — run the full test suite locally. If tests fail, spawn a `general` task to fix and re-run until green. Do not rely on CI to catch test failures — run locally first.
2. **Verify** — use your `verify` capability on the changes. If it returns blockers, spawn a `general` task to fix and re-run until clean.
3. **QA** — if the diff touches UI, views, or user-facing flows, use your `qa` capability. If it fails, spawn a `general` task to fix and re-run.
4. **Acceptance criteria** — verify each criterion from the original issue is met.

Fix all issues before proceeding. Do not surface findings to the user — resolve them first.

**Gate:** Tests green, no review blockers, QA passing, and acceptance criteria met.

---

## Phase 6: Learn

Follow the instructions in `learn.md` (bundled with this skill). Capture any non-obvious discoveries, hidden dependencies, or workarounds from this session.

**Gate:** Learning capture complete.

---

## Phase 7: User Approval → Commit

Present a summary of what was implemented, confirming tests, review, QA, and learn are all complete. STOP and wait for explicit approval before committing.

**Gate:** Wait for a clear "yes", "approved", "lgtm", or equivalent.

---

## Phase 8: Commit

Use your `commit` capability. It handles stage → test → commit automatically.

After committing, use your `push` capability for the push approval flow and CI watching.

---

## Skip Criteria

Skip Phases 1-3 for painfully simple tasks: typo fixes, single-line config changes, trivial one-file edits with no logic involved.

Even for simple tasks: always use Phases 7-8 (user approval + commit capability).
