---
description: address review feedback or conflicts on your merge request
agent: lead
---

Workflow: merge-request. You are maintaining your own merge request. Each phase below names what to dispatch or which skill to use — the methodology lives in the dispatched agents and skills.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Reopen issue — if the MR references a tracked issue, set it back to In Progress
- Triage — fetch threads + top-level comments, categorize, present for approval
- Fix — dispatch the `build` subagent (`task` tool, `subagent_type: build`, TDD), resolve fixed threads
- Conflicts — resolve if present, run tests
- Re-request — present summary, re-request review

## Reopen issue

If the merge request references a tracked issue/ticket (check the MR title, branch name, or description), set that issue back to In Progress before doing anything else — a returning MR's issue may be sitting in a review or done state. Use the appropriate issue-tracker skill for the org.

## Triage

Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to fetch both surfaces of feedback: review threads (inline diff comments) and top-level comments (`gh pr view --json comments`). Categorize each item as actionable (fix code), discussable (needs reply), or already resolved.

**Present the triage to the human. Wait for approval before proceeding.**

## Fix

For each actionable thread, dispatch the `build` subagent (`task` tool, `subagent_type: build`, strict TDD). After the fix commits, **resolve the thread** — no reply needed. Reserve replies for threads you are declining, deferring, questioning, or adding context to; always get approval before posting a reply.

## Conflicts

If the merge request conflicts with the target branch, resolve preserving both sides' intent (examine both sides, don't mechanically accept one). Run the full test suite after resolution. When the MR has existing reviews, use merge (not rebase) — rebasing invalidates inline comments.

## Re-request

Present a summary of what changed. After approval, re-request review from every reviewer who previously reviewed, with a comment summarizing what was addressed.

All remote writes (posting replies, pushing, re-requesting review) require explicit approval — use the `commit` and `push` skills for shipping.

$ARGUMENTS
