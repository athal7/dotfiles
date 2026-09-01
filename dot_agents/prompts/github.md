# GitHub

Check your actual tools rather than assuming a name exists — the surface evolves. Resolve repo/org context and identifiers with a read tool before any write; never guess a number.

## Starting a review

At `/review` start, inspect the pull request assignment. If it is unassigned, assign it to yourself. An assignee who is not you signals an in-flight review, even when the pull request is ready for review. Do not change its draft state, reviewers, or assignment. After `/review` submits, remove your self-assignment.

## Review threads

- **Fetch** — `pull_request_read` `method: get_review_comments`, which carries `isResolved`/`isOutdated`/`isCollapsed` per thread. Don't hand-roll GraphQL.
- **Two different IDs.** Reply (`add_reply_to_pull_request_comment`) takes the **numeric** `#discussion_r…` id of the thread's top comment. Resolve (`pull_request_review_write` `method: resolve_thread`) takes the **`PRRT_…` GraphQL node id**. Both come from the `get_review_comments` result.
- **Resolve only after the fix is pushed** — GitHub ties resolution to the commit that addressed it. Resolve silently; the resolution is the acknowledgment. Reply instead when declining, deferring, or adding context.
- **Line-anchored review** — pending review → `add_comment_to_pending_review` per finding → `method: submit`. One review event, not N standalone comments.
- **Line numbers are HEAD-commit file lines**, not diff offsets, and GitHub's display can be off by one. Cross-check `get_diff`/`get_files` before anchoring.
