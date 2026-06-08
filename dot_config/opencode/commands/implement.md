---
description: implement a change [issue|description], plan/build/review/ship
agent: lead
---

Workflow: implement.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Workspace setup — branch/worktree if needed per repo conventions
- Plan — dispatch the `explore`/`scout` subagents (`task` tool, `subagent_type: explore` / `subagent_type: scout`) to gather, dispatch the `plan` subagent (`task` tool, `subagent_type: plan`), create proposal, present for approval
- Build — implement tasks via openspec-apply-change, present changeset for approval
- Review — dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`, static), dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) if UI touched, route findings, present for approval
- Ship — commit, push, watch CI

## Workspace setup

Check the repo's AGENTS.md for branch conventions. If the repo uses feature branches and you're on `main`: load the `opencode` skill and use dispatch.md to create a worktree session for this work — the implementation should happen in an isolated worktree, not on main. If the repo commits directly to main (e.g., dotfiles), skip this step.

## Plan

Gather context, then get a design recommendation:

1. Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather internal context: relevant source files, git history, the referenced issue/PR/ticket, and any `openspec/specs/` requirements that constrain this change.
2. When the change involves unfamiliar libraries, dependencies, or external APIs, dispatch the `scout` subagent (`task` tool, `subagent_type: scout`) for external research (docs, dependency source, version constraints, changelogs) — alongside or before the `plan` subagent.
3. Dispatch the `plan` subagent (`task` tool, `subagent_type: plan`) with the user's request, the gathered context, any scout findings, and relevant spec constraints, asking "what should change and why?" Plan returns a structured recommendation with reasoning and tradeoffs.

Create an OpenSpec proposal to persist the plan: dispatch the `build` subagent (`task` tool, `subagent_type: build`) with `openspec-propose` to create proposal + design + tasks. The proposal is the plan artifact — it captures what changes, why, and the task breakdown. This step is mandatory, not conditional on change size.

**A missing `openspec/` folder is expected, not a problem.** `openspec/` is globally gitignored — it's session scratch space for the current plan, not committed artifacts. If the repo has no `openspec/` directory, create it and proceed; don't treat its absence as a blocker or try to commit it.

**Present the proposal for approval. Wait before proceeding.**

## Build

Load `openspec-apply-change` and work through the tasks. For each task, dispatch the `build` subagent (`task` tool, `subagent_type: build`) with strict TDD scope. Track progress via task checkboxes.

**Present the changeset for approval. Wait before proceeding.**

## Review

Dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) against the changeset. Reviewer owns the static review protocol (multi-pass analysis, verification) and returns findings classified by routing destination.

When the changeset touches UI (views, templates, CSS, frontend), also dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) for browser functional verification of the affected flows. Both reviewer and qa findings feed into the routing below.

**Route the returned findings:**
- **Build-level** (bug, style, missing test) → dispatch the `build` subagent (`task` tool, `subagent_type: build`) for a targeted fix, then re-dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) on the fix
- **Plan-level** (wrong approach, missing requirement) → re-dispatch the `plan` subagent (`task` tool, `subagent_type: plan`), update the proposal
- **Human judgment** (tradeoff, scope question) → present to the user and wait

**Present the review for approval before proceeding.**

## Ship

Load `commit` skill for staging, test verification, and commit message format. Then load `push` skill for branch naming, merge request creation, and CI watching. All remote actions require explicit approval.

**CI failure → diagnose and route:** code fix → dispatch the `build` subagent (`task` tool, `subagent_type: build`). Approach problem → re-dispatch the `plan` subagent (`task` tool, `subagent_type: plan`). Flaky test → re-run. Do not treat CI failure as terminal.

$ARGUMENTS
