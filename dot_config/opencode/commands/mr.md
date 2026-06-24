---
description: address review feedback or conflicts on your merge request
agent: lead
---

Workflow: merge-request. You are maintaining your own merge request. Each phase below names what to dispatch or which skill to use — the methodology lives in the dispatched agents and skills.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Reopen issue — if the MR references a tracked issue, set it back to In Progress
- Triage — fetch threads + top-level comments, categorize, present for approval
- Fix — dispatch the `build` subagent (`task` tool, `subagent_type: build`, TDD); run QA (dispatch the `qa` subagent) before commit/push when UI is touched; resolve fixed threads, and seek deterministic fitness functions for repo conventions
- Conflicts — resolve if present, run tests
- Re-request — present summary, re-request review

## Reopen issue

If the merge request references a tracked issue/ticket (check the MR title, branch name, or description), set that issue back to In Progress before doing anything else — a returning MR's issue may be sitting in a review or done state. Use the appropriate issue-tracker skill for the org.

## Triage

Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to fetch both surfaces of feedback: review threads (inline diff comments) and top-level comments (`gh pr view --json comments`). Categorize each item as actionable (fix code), discussable (needs reply), or already resolved.

**Present the triage to the human. Wait for approval before proceeding.**

## Fix

For each actionable thread, dispatch the `build` subagent (`task` tool, `subagent_type: build`, strict TDD).

**Run QA before committing or pushing any fix that touches UI.** When a fix changes views, templates, CSS, or frontend, dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) for browser functional verification of the affected flows *before* the commit/push gate. Route findings as `/implement`'s Review does: build-level (bug, style, missing test) → re-dispatch the `build` subagent for a targeted fix, then re-verify; plan-level (wrong approach, missing requirement) → reconsider the fix with the human; human judgment (tradeoff, scope) → present and wait. Only once QA passes do you proceed to commit/push; skip QA for non-UI fixes. After the fix commits and pushes, **resolve the thread silently — do not post a reply.** The resolution *is* the acknowledgment; a "Fixed in abc123" reply is noise. Reply only when you are *not* simply fixing it — declining, deferring, questioning, or adding context — and always get approval before posting any reply.

**Seek deterministic fitness functions.** Repetition is hard to see inside a single changeset, so don't wait to spot an issue twice. Ask instead whether the feedback expresses a *convention* the repo should hold everywhere — a naming rule, an architectural boundary, a banned pattern. The strongest signal is feedback that points at guidance already written down — a documented convention or an agent instruction that keeps getting missed; a soft nudge that isn't being followed is a prime candidate to replace with something deterministic rather than restate. When the feedback names a convention, look for the opportunity to encode it as a deterministic check (a custom lint rule such as a custom RuboCop cop, a test, or a CI gate) so it self-enforces and no reviewer has to flag it again. A genuine one-off just gets fixed. Propose the rule as a follow-up and get approval before adding it; if it is out of scope for the current MR, capture it as a follow-up todo rather than expanding the diff.

## Conflicts

If the merge request conflicts with the target branch, resolve preserving both sides' intent (examine both sides, don't mechanically accept one). Run the full test suite after resolution. When the MR has existing reviews, use merge (not rebase) — rebasing invalidates inline comments.

## Re-request

Present a summary of what changed. After approval, re-request review from every reviewer who previously reviewed, with a comment summarizing what was addressed.

**Refresh the QA-evidence report in your description.** This assumes a prior `/implement` ship already created the marked block and the `qa-<ts>` session dir. After fixes land and with (or before) re-requesting review, refresh the `<sub>` provenance over the standing QA evidence, then upsert the refreshed block into your MR description — an in-place read-modify-write of the whole marked block between the `<!-- qa:start -->` / `<!-- qa:end -->` markers, never a new comment. Load the `qa-report-publish` skill for the mechanics.

All remote writes (posting replies, pushing, re-requesting review) require explicit approval — use the `commit` and `push` skills for shipping.

$ARGUMENTS
