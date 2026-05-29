---
description: address review feedback or conflicts on your merge request
---

Workflow: merge-request. You are maintaining your own merge request.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Triage — fetch review threads AND top-level comments, plan stance per item, present for approval
- Fix — implement fixes (TDD), post replies for declines
- Conflicts — resolve if present, run tests
- Review — run review passes against changes
- Ship — commit, push, verify thread coverage, re-request review

## Triage

Fetch two surfaces of feedback — they are distinct and both need a stance:
- **Review threads** (inline diff comments): note thread ID, file, line, comment body, author, resolved status.
- **Top-level comments** (conversation comments posted outside any review, via `gh pr view --json comments`): note comment ID, body, author. These have no resolve mechanism.

Plan a stance per item — `fix` or `decline-with-reason` — before any code changes. Do not propose follow-up issues as a stance; if work is tracked elsewhere, that is a decline whose reason cites the existing tracking.

Verify the plan: every item has a stance, fix-stance has a test-first approach, decline-stance has a substantive reason.

**Present the triage plan. Wait for approval before proceeding.**

## Fix

Work through every item:
- **Review thread — fix:** dispatch to build with strict TDD. Present a per-file summary (reviewer comment beside addressing diff) and wait for acknowledgement, then commit. Resolve the thread — no reply needed.
- **Review thread — decline:** do NOT resolve. Post an inline reply on the thread explaining why the code isn't changing.
- **Top-level comment — fix or decline:** top-level comments cannot be resolved. Always post a reply (via `gh pr comment`): for a fix, briefly note what changed; for a decline, explain why the code isn't changing.

Rules: resolve a review thread silently when a commit fixes it — no "fixed" reply. Reply without resolving when declining a thread — never silently resolve a disagreement. Never resolve a thread you didn't fix. Top-level comments always get a reply since they can't be resolved.

## Conflicts

If the merge request has conflicts with the target branch: examine both sides of each conflict, understand the intent of both, resolve preserving both sides' intent. Run the full test suite after resolution.

When the merge request has existing reviews, use merge (not rebase) — rebasing invalidates inline comments.

## Review

Run these passes against your changes:
1. **Reviewability** — diff is clean, changes are related.
2. **Correctness** — fixes match reviewer intent, no regressions.
3. **Code quality** — naming, duplication, pre-existing patterns.

Verify findings by attempting to disprove each one.

## Ship

Load `commit` and `push` skills. Push, then verify coverage: re-fetch both review threads and top-level comments — every review thread must be either resolved or have a reply from you, and every top-level comment must have a reply from you. Re-request review from every reviewer who previously reviewed.

All remote writes (posting replies, pushing, re-requesting review) require explicit approval.

$ARGUMENTS
