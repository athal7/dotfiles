---
name: respond-to-review
description: Address review feedback on your own merge request — resolve threads fixed by a commit, reply to threads you are not addressing
license: MIT
compatibility: opencode
metadata:
  provides:
    - respond-to-review
  requires:
    - source-control
    - push
    - verify
---

1. **Fetch all open review threads.** Note thread ID, file, line, comment body, author, resolved status.

2. **Plan a stance per thread** as a list — `fix` or `decline-with-reason` — before any code changes. Do not propose follow-up issues or deferred work as a stance; if the work is genuinely tracked elsewhere, that is a `decline-with-reason` whose reason cites the existing tracking.

3. **Verify the plan:** every thread has a stance, fix-stance has a test-first approach, decline-stance has a substantive reason. Apply findings.

4. **Work through every thread:**
   - **Fix:** follow strict red/green/refactor (your standing TDD instructions apply). Present a per-file summary (reviewer comment beside addressing diff) and wait for acknowledgement, then commit with a message referencing the feedback. Resolve the thread — no reply needed.
   - **Decline:** do NOT resolve. Post an inline reply on the thread (not a top-level comment) using the thread's top comment ID, explaining why the code isn't changing.

5. **Push.** The source control host ties thread resolution to the commit, so push before resolving or replying.

6. **Verify coverage.** Re-fetch threads; every one must be either resolved or have a reply from you. Never hand back with threads that have neither.

7. **Re-request review** from every reviewer who previously reviewed.

**Rules:**

- Resolve silently when a commit fixes — no "fixed" reply.
- Reply without resolving when declining — never silently resolve a disagreement.
- Never resolve a thread you didn't fix.
