---
name: merge-request
description: Maintain your own merge request — triage review threads, batch fixes, resolve conflicts, re-request review. Load when addressing feedback or conflicts on a request you own.
license: MIT
---

Track these five phases as a checklist before starting.

## 1. Draft

References a tracked issue? Mark the request a draft before anything else — a returning request may still be marked ready from a previous pass. Where the tracker syncs status from request state (Linear's GitHub integration), the linked issue updates from this alone; **don't also write to the tracker**.

## 2. Triage

Fetch **both** surfaces: inline review threads and top-level comments. Categorize each as actionable (fix code), discussable (needs reply), or already resolved.

**Present the triage. Wait.**

## 3. Fix

Batch the whole cycle: fix every actionable thread first, then **one** commit and push, then resolve every fixed thread together.

**QA before that push** if any fix touches views, templates, CSS, or frontend — once, covering every UI-touching fix. Route findings as implement's Review does. Skip entirely when no fix touches UI.

**Resolve silently, in one pass** — no comment, just mark resolved.

**Batch the non-fix replies** — declines, deferrals, questions, added context. Draft them together, present every reply's full text as one approval, then post consecutively.

**Look for a fitness function.** Repetition is invisible inside a single changeset, so don't wait to see an issue twice. Ask whether the feedback expresses a *convention* the repo should hold everywhere — a naming rule, an architectural boundary, a banned pattern. The strongest signal is feedback pointing at guidance already written down that keeps getting missed: a soft nudge nobody follows is a prime candidate to replace with a lint rule, test, or CI gate rather than restate.

## 4. Conflicts

Resolve preserving both sides' intent — examine both, never mechanically accept one. Run the full suite after. **Merge, don't rebase, when the request has existing reviews** — rebasing invalidates inline comments.

## 5. Re-request

Present a summary. After approval, mark ready for review (the linked issue's status follows automatically) and re-request from every previous reviewer — no comment, the diff speaks for itself.

**Refresh the QA evidence** in the description if a prior ship created the marked block: an in-place read-modify-write of the whole span between the `<!-- qa:start -->` / `<!-- qa:end -->` markers — never a new comment. Mechanics in `qa-report-publish`.

Push via `commit` and `push`. Reply content is shown in full for steering; batch same-turn replies into one presentation.
