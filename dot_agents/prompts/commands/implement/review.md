Changeset touches UI (views, templates, CSS, frontend) → dispatch `qa` for browser verification of the affected flows.

Static and blast-radius review is **not** inline — it happens automatically on the pushed merge request.

| Finding | Route |
|---|---|
| Bug, style, missing test | `build` (or direct, if you have edit/write and it's small), then re-verify |
| Wrong approach, missing requirement | Update the proposal |
| Tradeoff or scope question | Carry into the gate |

**Present the diff, the QA report, and any carried findings. Wait.** (`lumen diff --save-viewed` persists per-file viewed state locally.)

Ends with: an approved changeset + QA.
