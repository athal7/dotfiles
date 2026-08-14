Changeset touches UI (views, templates, CSS, frontend) → dispatch `qa` for browser verification of the affected flows (on omp, no standing `qa` agent exists — construct the task() dispatch from `qa-verification`, the skill both this and opencode's persona load).

Static and blast-radius review is **not** inline — it happens automatically on the pushed merge request.

| Finding | Route |
|---|---|
| Bug, style, missing test | `build` (or direct, if you have edit/write and it's small), then re-verify |
| Wrong approach, missing requirement | Update the proposal |
| Tradeoff or scope question | Carry into the gate |

**Present an understanding-first explanation of the diff (background first, intuition before details, literate diff narrative, and optional micro-worlds or comprehension checks), the QA report, and any carried findings. Wait.** (`lumen diff --save-viewed` persists per-file viewed state locally.)

Ends with: an approved changeset + QA.
