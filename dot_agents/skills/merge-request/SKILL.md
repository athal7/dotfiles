---
name: merge-request
description: "Maintain your own merge request — triage review threads, batch fixes, resolve conflicts, re-request review."
---

Use native `github` operations for repository, issue, PR, search, checkout, push, and Actions-watch work.
Use approval-gated `gh api` only when native GitHub support does not cover the operation.
Show the full payload and ask `Do you approve?` before every remote write.

## Draft state

Do not disrupt an active reviewer.
An assignee who is not you means review is in progress.
Do not change draft state, reviewers, or assignment in that case.
A reviewer who has left threads is done reviewing.
Do not flip the request back to draft while you fix their feedback.

Mark the request draft only when there is no other assignee and you must make unrequested changes.
Leave a comment first so reviewers know to stop.
Where tracker sync follows request state, do not also write to the tracker.

## Triage

Fetch both inline review threads and top-level comments.
Classify each comment as actionable, discussable, or already resolved.

Present each comment before acting:

1. Full comment text, location, author, and timestamp.
2. Relevant code context and thread state.
3. Proposed fix or exact reply text.

Wait for approval on every fix and every reply.

## Fix cycle

Batch the work.
Fix every approved actionable thread first.
Run QA first if any fix touches UI, templates, CSS, or frontend code.
Commit and push once.
Resolve fixed threads silently after the fix is pushed.

Batch non-fix replies.
Present all reply text for approval.
Post the approved replies consecutively.

Look for a fitness function.
If feedback expresses a rule the repository should always enforce, propose a lint rule, test, or CI gate instead of only restating the rule.

## Conflicts

Resolve conflicts by preserving both sides' intent.
Examine both sides.
Do not mechanically accept one side.
Run the full required suite after conflict resolution.
Merge instead of rebase when the request already has reviews.
Rebasing invalidates inline comments.

## Re-request

Present the final summary first.
After approval, mark ready and re-request previous reviewers.
Do not add a comment unless a policy above requires it.
Refresh QA evidence in the description if a prior ship added the `<!-- qa:start -->` block.
Use the `qa-report-publish` skill for that update.
Re-request only at a stable moment.
