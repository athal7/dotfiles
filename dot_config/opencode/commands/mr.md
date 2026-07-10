---
description: address review feedback or conflicts on your merge request
agent: lead
---

Workflow: merge-request. You are maintaining your own merge request. Each phase below names what to dispatch or which skill to use — the methodology lives in the dispatched agents and skills.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Draft PR — if the MR references a tracked issue, mark the PR as draft (linked issue status updates automatically)
- Triage — fetch threads + top-level comments, categorize, present for approval
- Fix — dispatch the `build` subagent (`task` tool, `subagent_type: build`, TDD) for all actionable threads first; run QA (dispatch the `qa` subagent) before the one batched commit/push when UI is touched; resolve all fixed threads together and batch non-fix replies into one approval; seek deterministic fitness functions for repo conventions
- Conflicts — resolve if present, run tests
- Re-request — present summary, mark ready for review, re-request review

## Draft

If the merge request references a tracked issue/ticket (check the MR title, branch name, or description), mark the pull request as a draft before doing anything else — a returning MR's PR may still be marked ready for review from a previous pass. Dispatch the `github` subagent (`task` tool, `subagent_type: github`) to convert the PR to draft. If the org's issue tracker syncs status from PR state (e.g. Linear's GitHub integration), the linked issue's status updates automatically from this alone — do not also write to the issue tracker directly.

## Triage

Dispatch the `github` subagent (`task` tool, `subagent_type: github`) to fetch both surfaces of feedback: review threads (inline diff comments, via `pull_request_read method:get_review_comments`) and top-level comments. Categorize each item as actionable (fix code), discussable (needs reply), or already resolved.

**Present the triage to the human. Wait for approval before proceeding.**

## Fix

For each actionable thread, dispatch the `build` subagent (`task` tool, `subagent_type: build`, strict TDD) — batch the whole cycle across all actionable threads: fix every thread first, then commit and push once, then resolve every fixed thread together.

**Run QA before the batched commit/push if any fix touches UI.** When any fix changes views, templates, CSS, or frontend, dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) for browser functional verification of the affected flows *before* the commit/push gate — once, covering every UI-touching fix together. Route findings as `/implement`'s Review does: build-level (bug, style, missing test) → re-dispatch the `build` subagent for a targeted fix, then re-verify; plan-level (wrong approach, missing requirement) → reconsider the fix with the human; human judgment (tradeoff, scope) → present and wait. Only once QA passes do you proceed to the one commit/push covering every fix; skip QA entirely when no fix touches UI.

**One push, one resolution pass.** Once all fixes have landed in that single commit/push, dispatch the `github` subagent to **resolve every fixed thread silently, without a reply** (`pull_request_review_write method:resolve_thread`), one dispatch covering all of them — the resolution is the acknowledgment.

**Batch the non-fix replies too.** For threads you are *not* simply fixing — declining, deferring, questioning, or adding context — draft all of their replies together and present them as one approval showing every reply's full text (content-bearing writes are shown in full for steering, per remote-operations). After approval, post them consecutively to the `github` subagent.

**Seek deterministic fitness functions.** Repetition is hard to see inside a single changeset, so don't wait to spot an issue twice. Ask instead whether the feedback expresses a *convention* the repo should hold everywhere — a naming rule, an architectural boundary, a banned pattern. The strongest signal is feedback that points at guidance already written down — a documented convention or an agent instruction that keeps getting missed; a soft nudge that isn't being followed is a prime candidate to replace with something deterministic rather than restate. When the feedback names a convention, look for the opportunity to encode it as a deterministic check (a custom lint rule such as a custom RuboCop cop, a test, or a CI gate) so it self-enforces and no reviewer has to flag it again. A genuine one-off just gets fixed. Propose the rule as a follow-up and get approval before adding it; if it is out of scope for the current MR, capture it as a follow-up todo rather than expanding the diff.

## Conflicts

If the merge request conflicts with the target branch, resolve preserving both sides' intent (examine both sides, don't mechanically accept one). Run the full test suite after resolution. When the MR has existing reviews, use merge (not rebase) — rebasing invalidates inline comments.

## Re-request

Present a summary of what changed. After approval, dispatch the `github` subagent to mark the pull request ready for review again (undo draft status — the linked issue's status updates automatically), then re-request review from every reviewer who previously reviewed, with a comment summarizing what was addressed.

**Refresh the QA-evidence report in your description.** This assumes a prior `/implement` ship already created the marked block and the `qa-<ts>` session dir. After fixes land and with (or before) re-requesting review, refresh the `<sub>` provenance over the standing QA evidence, then upsert the refreshed block into your MR description — an in-place read-modify-write of the whole marked block between the `<!-- qa:start -->` / `<!-- qa:end -->` markers, never a new comment. Load the `qa-report-publish` skill for the mechanics.

Push using the `commit` and `push` skills. Reply and re-request-review content is shown in full for steering. Batch same-turn replies (declines, deferrals, the re-request comment) into one presentation.

$ARGUMENTS
