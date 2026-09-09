---
name: implement
description: "The full implementation loop — issue, workspace, plan, build, review, ship. Load when starting or resuming work on a change, or when the user invokes the implement workflow."
---

Native OMP owns plan mode, todo tracking, task agents, commit execution, and native GitHub operations.
This skill adds repository policy only.

## Issue

Every change needs a tracker reference unless tracking is unavailable and the user approves untracked work.
If the request names an issue, fetch it first.
If no issue is named, search for a matching open or recently closed issue.
If there is no clear match, draft the title and short what/why text before creating an issue.
Set the issue In Progress before code work when the tracker supports it.
Do not manually transition an issue when a linked merge request integration will do it.
List real tracker state names before selecting one.

## Workspace

Follow the repository branch rules.
If already in a worktree or feature branch, continue there.
If on `main` in a feature-branch repository, create a branch from `origin/main`.
If the repository deploys from main, work in place.
Do not create a worktree from this skill.
Session tooling owns worktree isolation.

## Plan

Gather the source, issue, history, and constraints that affect the change.
Use existing repository patterns.
Do not add a second convention beside an existing one.
Persist the plan and get approval when the request is not already backed by an approved plan.
State open questions only when tools cannot answer them.

## Build

Implement the approved scope only.
Fix root causes instead of suppressing symptoms.
Migrate all call sites for a changed contract.
Remove obsolete code, aliases, re-exports, and deprecated paths.
Do not leave stubs, placeholders, mocks, no-ops, or `TODO: implement` markers.
Write no explanatory code comments.
Use names and structure to carry intent.

## Review

Verify the changed behavior before presenting it.
For UI changes, drive the app in a browser and capture evidence.
For bug fixes, reproduce the bug and then show that the reproduction no longer fails.
For permanent API or feature changes, run the existing tests that cover the contract.
Add tests only when there is a new observable contract or the user asks for tests.

Present the diff, the reasoning for the diff, verification evidence, and carried risks when a human approval gate is required.

## Ship

Load `commit` before committing.
Load `push` before pushing.
For this chezmoi repository, deploy with `chezmoi-deploy <branch>` instead of opening a pull request.
For pull-request repositories, push and complete the CI and automated-review watch loop.
