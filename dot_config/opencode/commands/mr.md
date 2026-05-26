---
description: address review feedback or conflicts on your merge request
---

Workflow: merge-request. You are maintaining your own merge request.

## Triage

Fetch all open review threads. For each thread, note: thread ID, file, line, comment body, author, resolved status.

Plan a stance per thread — `fix` or `decline-with-reason` — before any code changes. Do not propose follow-up issues as a stance; if work is tracked elsewhere, that is a decline whose reason cites the existing tracking.

Verify the plan: every thread has a stance, fix-stance has a test-first approach, decline-stance has a substantive reason.

**Present the triage plan. Wait for approval before proceeding.**

## Fix

Work through every thread:
- **Fix:** dispatch to build with strict TDD. Present a per-file summary (reviewer comment beside addressing diff) and wait for acknowledgement, then commit. Resolve the thread — no reply needed.
- **Decline:** do NOT resolve. Post an inline reply on the thread explaining why the code isn't changing.

Rules: resolve silently when a commit fixes — no "fixed" reply. Reply without resolving when declining — never silently resolve a disagreement. Never resolve a thread you didn't fix.

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

Load `commit` and `push` skills. Push, then verify thread coverage: re-fetch threads — every one must be either resolved or have a reply from you. Re-request review from every reviewer who previously reviewed.

All remote writes (posting replies, pushing, re-requesting review) require explicit approval.

$ARGUMENTS
