---
description: review someone else's merge request [pr|branch|commit], defaults to uncommitted
agent: lead
---

Workflow: review someone else's merge request. Each phase below names what to dispatch — the methodology lives in the dispatched agents and skills.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Setup — dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather diff, rules, acceptance criteria, bot comments
- Review — dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) for findings grouped by acceptance criterion; dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) if UI is touched
- Walk — reveal the grouped findings one group at a time, pausing after each for the user's triage; carry survivors forward as proposed comments
- Submit — present the surviving comments, post inline after approval; when QA ran, also publish the QA report (`qa-publish` skill) after approval

## Setup

Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather everything the review needs for $ARGUMENTS:
- The target diff — route a PR number, branch name, or commit SHA accordingly; default to uncommitted changes when no argument is given.
- The project rules (`AGENTS.md` root + nested, `CONVENTIONS.md`, `REVIEW.md`, `CONTRIBUTING.md`, `docs/` guides).
- The linked ticket's **acceptance criteria** — fetch them from the change's linked tracker (load the matching tracker skill); formats vary, so parse what's there and fall back to the PR description when there's no structured AC.
- Any existing automated/bot review comments already on the request.

## Review

Dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) with the diff, the project rules, the acceptance criteria, and the bot comments. It organizes its analysis as **AC → tests → code** logical groups, runs the blast-radius sweep for callers/callees outside the PR, then the multi-pass static analysis, and returns its findings **grouped by acceptance criterion** (each group carries its `file:line` anchors and the findings against it), classified by routing destination, flagging whether QA is needed.

When the diff touches UI (views, templates, CSS, frontend), also dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) for browser functional verification of the affected flows.

On a **re-review** (the author pushed since a prior pass), scope to the delta. Diff the new commits against the prior-reviewed state, map the changed lines onto the AC groups, and re-dispatch the `reviewer` for only the touched groups — reconciling prior findings (`addressed` / `pending` / `moved-but-still-true`). Untouched groups keep their prior verdict, and the Walk covers only the changed groups plus any still-open findings. Same judgement for `qa`: re-dispatch only when the new commits touch UI or address a prior QA finding, scoped to the affected flows; non-UI changes leave the prior QA verdict standing.

## Walk

Reveal the reviewer's findings to the user **one group at a time**, in the reviewer's order — don't dump every group at once; the review is a conversation. For each group: name the acceptance criterion, point to its `file:line` anchors (the user opens them in their Review pane), present that group's findings, then **pause** for the user's triage — dismiss, accept, mark intentional, or ask you to dig deeper. Carry the surviving findings forward as proposed inline comments.

## Submit

Post the surviving findings as **inline comments** on the changed lines — no verdict or summary in the submitted body. All remote writes require explicit human approval: show the full proposed text of every comment and **wait** for approval before posting. When the MR has existing reviews and merge conflicts, use merge (not rebase) — rebasing invalidates existing inline comments.

When QA ran, also publish its report — load the `qa-publish` skill and follow it (approval gate, then publish) — separate from and in addition to the inline reviewer findings.

$ARGUMENTS
