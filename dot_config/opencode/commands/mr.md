---
description: address review feedback or conflicts on your merge request
agent: lead
---

Workflow: merge-request. You are maintaining your own merge request. Each phase below names what to dispatch or which skill to use — the methodology lives in the dispatched agents and skills.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Reopen issue — if the MR references a tracked issue, set it back to In Progress
- Triage — fetch threads + top-level comments, categorize, present for approval
- Fix — dispatch the `build` subagent (`task` tool, `subagent_type: build`, TDD), resolve fixed threads, and seek deterministic fitness functions for repo conventions
- Conflicts — resolve if present, run tests
- Re-request — present summary, re-request review

## Reopen issue

If the merge request references a tracked issue/ticket (check the MR title, branch name, or description), set that issue back to In Progress before doing anything else — a returning MR's issue may be sitting in a review or done state. Use the appropriate issue-tracker skill for the org.

## Triage

Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to fetch both surfaces of feedback: review threads (inline diff comments) and top-level comments (`gh pr view --json comments`). Categorize each item as actionable (fix code), discussable (needs reply), or already resolved.

**Present the triage to the human. Wait for approval before proceeding.**

## Fix

For each actionable thread, dispatch the `build` subagent (`task` tool, `subagent_type: build`, strict TDD). After the fix commits, **resolve the thread** — no reply needed. Reserve replies for threads you are declining, deferring, questioning, or adding context to; always get approval before posting a reply.

**Seek deterministic fitness functions.** Repetition is hard to see inside a single changeset, so don't wait to spot an issue twice. Ask instead whether the feedback expresses a *convention* the repo should hold everywhere — a naming rule, an architectural boundary, a banned pattern. The strongest signal is feedback that points at guidance already written down — a documented convention or an agent instruction that keeps getting missed; a soft nudge that isn't being followed is a prime candidate to replace with something deterministic rather than restate. When the feedback names a convention, look for the opportunity to encode it as a deterministic check (a custom lint rule such as a custom RuboCop cop, a test, or a CI gate) so it self-enforces and no reviewer has to flag it again. A genuine one-off just gets fixed. Propose the rule as a follow-up and get approval before adding it; if it is out of scope for the current MR, capture it as a follow-up todo rather than expanding the diff.

## Conflicts

If the merge request conflicts with the target branch, resolve preserving both sides' intent (examine both sides, don't mechanically accept one). Run the full test suite after resolution. When the MR has existing reviews, use merge (not rebase) — rebasing invalidates inline comments.

## Re-request

Present a summary of what changed. After approval, re-request review from every reviewer who previously reviewed, with a comment summarizing what was addressed.

**Refresh the review report in your description.** After fixes land and with (or before) re-requesting review, regenerate the local forms (`review-report.html` + `review-report.md`), re-host the `.md`, and upsert the Template-A collapsed-AC block into your OWN merge request **description** between the `<!-- qa:start -->` / `<!-- qa:end -->` markers — an in-place read-modify-write of the whole marked block (refresh the `<sub>` provenance), never a new comment. Load the `review-publish` skill for the mechanics.

All remote writes (posting replies, pushing, re-requesting review) require explicit approval — use the `commit` and `push` skills for shipping.

$ARGUMENTS
