---
name: merge-request
description: Load when maintaining your own pull request after review feedback or conflicts
license: MIT
---

- Fetch inline review threads and top-level comments.
- Classify each item as actionable, discussable, or resolved.
- Present the full comment, location, author, timestamp, relevant code, and proposed action before changing code or replying.
- Batch actionable fixes. Run the lowest suitable verification tier. Run browser QA first for UI changes.
- Use `shipit` for the commit and push cycle.
- Copilot code review resolves its own comments during its rereview once a pushed commit addresses the feedback. After pushing, wait for that rereview and treat the still-open comments as the outstanding feedback; do not hand-resolve an addressed thread to make the set look clean. Hand-resolve only what Copilot leaves open, choosing the resolution reason (`Addressed`, `Won't fix`, `Incorrect`).
- For a review with comment threads, dismiss the review after every thread has been replied to, fixed (and pushed), or resolved.
- The configured GitHub MCP lacks review dismissal. Use `gh api` through Bash for REST `PUT /repos/{owner}/{repo}/pulls/{pull_number}/reviews/{review_id}/dismissals` with `{"message": "<reason>", "event": "DISMISS"}`; confirm the returned review `state` is `DISMISSED`.
- On a protected branch, dismissal requires administrator or designated dismissal permission; report a denied dismissal rather than treating thread resolution as equivalent.
- `Fix with Copilot` / `Fix batch with Copilot` on a review comment hands it to Copilot cloud agent, which commits to this PR branch or opens a PR against it. Use it for mechanical or wide-sweeping feedback (renames, lint and test updates, repeated nits) and for feedback you would otherwise leave stalled while blocked elsewhere; fix design comments in-session. Hand off only feedback with no fix in flight, then fetch the branch and check the author of any new commit before building on it.
- A Copilot approval counts toward required approvals but behaves like a human one: any later commit dismisses it. Re-request the review for the new head instead of carrying the previous approval forward.
- Leave pending reviewer requests untouched.
- Resolve conflicts by preserving both sides' intent. Run the full required checks after resolution.
- After the final summary and stable head are pushed, use `shipit` to request or trigger configured bot reviews for that head. Once its readiness gates are met, mark a draft PR ready before requesting or waiting for human review; re-request only affected completed human reviews—not reviewers still pending. Treat prior-head results as stale.
- Inspect auto-merge and merge-queue state before and after each fix push. Preserve valid existing intent; pushes can disable auto-merge or remove queue membership, so verify against the new head rather than trusting the earlier setting.
- Once ready, follow `shipit`'s deferred-merge policy to enable or re-arm auto-merge or the required queue before waiting for protected human approvals. Confirm the server's armed/queued state and report it; do not leave an eligible PR needing another manual visit to merge.
- Prefer merging over rebasing a reviewed request; rebasing can invalidate inline comment anchors.
