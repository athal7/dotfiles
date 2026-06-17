---
description: review someone else's merge request [pr|branch|commit], defaults to uncommitted
agent: lead
---

Workflow: review someone else's merge request. Each phase below names what to dispatch — the methodology lives in the dispatched agents and skills.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Setup — dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather diff, rules, issue context, bot comments
- Review — dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) for classified findings; dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) if UI is touched
- Submit — present proposed comments, post inline after approval; when QA ran, also publish the QA report (`qa-publish` skill) after approval

## Setup

Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather everything the review needs for $ARGUMENTS:
- The target diff — route a PR number, branch name, or commit SHA accordingly; default to uncommitted changes when no argument is given.
- The project rules (`AGENTS.md` root + nested, `CONVENTIONS.md`, `REVIEW.md`, `CONTRIBUTING.md`, `docs/` guides).
- Issue/acceptance-criteria context linked to the change.
- Any existing automated/bot review comments already on the request.

## Review

Dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) with the diff, the project rules, and the bot comments. It runs the multi-pass static analysis and returns findings classified by routing destination, flagging whether QA is needed.

When the diff touches UI (views, templates, CSS, frontend), also dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) for browser functional verification of the affected flows.

## Submit

Post the findings as **inline comments** on the changed lines — no verdict or summary in the submitted body. All remote writes require explicit human approval: show the full proposed text of every comment and **wait** for approval before posting. When the MR has existing reviews and merge conflicts, use merge (not rebase) — rebasing invalidates existing inline comments.

When QA ran, also publish its report — load the `qa-publish` skill and follow it (approval gate, then publish) — separate from and in addition to the inline reviewer findings.

$ARGUMENTS
