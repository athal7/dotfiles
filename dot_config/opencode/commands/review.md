---
description: review someone else's merge request [pr|branch|commit], defaults to uncommitted
agent: lead
---

Workflow: review someone else's merge request. Each phase below names what to dispatch — the methodology lives in the dispatched agents and skills.

**Use TodoWrite to track this workflow. Create these items before starting:**
- Setup — dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather diff, rules, acceptance criteria, bot comments
- Review — dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) for findings grouped by acceptance criterion; dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) if UI is touched
- Submit — assemble the unified review report (reviewer findings + qa evidence, by AC) as your worktable, host the `.md`, then deliver by ownership (`review-publish` skill) after approval

## Setup

Dispatch the `explore` subagent (`task` tool, `subagent_type: explore`) to gather everything the review needs for $ARGUMENTS:
- The target diff — route a PR number, branch name, or commit SHA accordingly; default to uncommitted changes when no argument is given.
- The project rules (`AGENTS.md` root + nested, `CONVENTIONS.md`, `REVIEW.md`, `CONTRIBUTING.md`, `docs/` guides).
- The linked ticket's **acceptance criteria** — fetch them from the change's linked tracker (load the matching tracker skill); formats vary, so parse what's there and fall back to the PR description when there's no structured AC.
- Any existing automated/bot review comments already on the request.

## Review

Dispatch the `reviewer` subagent (`task` tool, `subagent_type: reviewer`) with the diff, the project rules, the acceptance criteria, and the bot comments. It organizes its analysis as **AC → tests → code** logical groups, runs the blast-radius sweep for callers/callees outside the PR, then the multi-pass static analysis, and returns its findings **grouped by acceptance criterion** (each group carries its `file:line` anchors and the findings against it), classified by routing destination, flagging whether QA is needed.

When the diff touches UI (views, templates, CSS, frontend), also dispatch the `qa` subagent (`task` tool, `subagent_type: qa`) for browser functional verification of the affected flows.

On a **re-review** (the author pushed since a prior pass), scope to the delta. Diff the new commits against the prior-reviewed state, map the changed lines onto the AC groups, and re-dispatch the `reviewer` for only the touched groups — reconciling prior findings (`addressed` / `pending` / `moved-but-still-true`). Untouched groups keep their prior verdict. Lead then REGENERATES the unified report from the reconciled findings. Same judgement for `qa`: re-dispatch only when the new commits touch UI or address a prior QA finding, scoped to the affected flows; non-UI changes leave the prior QA verdict standing.

## Submit

Lead ASSEMBLES the unified review report in BOTH forms: interleave the reviewer's AC-grouped findings with qa's per-AC evidence, one section per acceptance criterion, into `review-report.html` (local-only — embeds the rendered diffs + screenshots + running-app links) AND `review-report.md` (hosted — deep-links the diffs, relative-ref screenshots) in qa's session dir (so the relative screenshot refs resolve). When QA did NOT run, lead still creates the `qa-<ts>` dir and writes both forms with verdict `n/a` (the diff/findings half is always present). These local + hosted forms are the reviewer's **worktable/record** — always generated, always hosted. Then load the `review-publish` skill and follow it — open the `.html` locally → host the `.md` → approval gate → deliver by ownership:

- **Someone else's merge request** (the usual `/review` target): submit ONE review — inline line-anchored comments drafted from the reviewer's findings PLUS a summary body (Template B: verdict badge, finding counts, per-AC outline, hosted-report link). One review event carries both. **Strip the internal `[build]`/`[human]`/`[plan]` routing tags from the author-facing inline comment bodies** — write self-contained, actionable prose; the classification stays internal (it still drives the body-summary counts). `event` is REQUEST_CHANGES with any blocker, COMMENT for nits/questions only, APPROVE when clean — and APPROVE ALWAYS goes through the explicit human approval gate; never auto-approve.
- **Your own merge request** (when `/review` targets a PR you authored): upsert the Template-A collapsed-AC block into the merge request **description** between `<!-- qa:start -->` / `<!-- qa:end -->` markers (in-place read-modify-write, never a new comment). Never edit another author's description.
- **Local / no merge request** (uncommitted or branch with no remote request): open the local HTML only — no remote write.

Guardrail: deliver findings AS line-anchored review comments — **no scattered standalone comments and no single top-level wall** of text substituting for the inline detail.

When the MR has existing reviews from OTHERS and merge conflicts arise, use merge (not rebase) — rebasing invalidates existing inline comments, including the ones this flow now posts.

$ARGUMENTS
