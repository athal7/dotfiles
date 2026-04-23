---
name: respond-to-review
description: Address review feedback on your own merge request — resolve threads fixed by a commit, reply to threads you are not addressing
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - respond-to-review
  requires:
    - source-control
---

Load this skill when you are fixing code in response to reviewer comments on your own merge request.

## Steps

1. **Fetch all open review threads** on the merge request using your `source-control` capability. For each thread, note: thread ID, file, line, comment body, author, resolved status.

2. **Work through every unresolved thread** — do not skip any:

   - **Fix it**: make the code change, commit with a message that references what reviewer feedback it addresses. Then **resolve the thread** via your `source-control` capability — no reply needed.
   - **Not fixing it**: do NOT resolve the thread. **Post an inline reply directly on the thread** (not a top-level PR comment) via your `source-control` capability, using the thread's top comment ID. Explain why the code is not changing (disagreement, won't fix, already handled elsewhere, etc.).

3. **Push** before resolving or replying — GitHub ties thread resolution to the commit on the branch. Push first, then resolve.

4. **Verify coverage**: after addressing all threads, re-fetch the thread list and confirm every thread is either resolved or has a reply from you. Do not hand back to the user with open threads that have neither.

## Rules

- Resolve without comment when a commit fixes the issue — do not add a "fixed" reply.
- Reply without resolving when you are not changing the code — do not silently resolve disagreements.
- Never resolve a thread that you did not fix. Never leave a thread with neither a resolve nor a reply.
- Show proposed replies to the user and wait for approval before posting — same as the approval gate for any write to a remote service.
