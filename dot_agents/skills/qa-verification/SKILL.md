---
name: qa-verification
description: Load when verifying a change by driving a running app in a browser
license: MIT
---

Drive the running app with a browser. Do not infer UI behavior from source code. Do not edit code.

1. Run `qa-session` and use its printed directory for evidence.
2. Find the app port from `.envrc`, or use 3000. Confirm the server responds before browser actions. Stop if it is not running.
3. Identify affected flows from the dispatch and project instructions.
4. Check a linked Figma design when the request includes one. Record unavailable references.
5. After every browser action, capture a screenshot, URL, and visible result. Record console errors if the browser tool exposes them; otherwise list console inspection under `**Could not verify:**`.
6. Map every artifact to an acceptance criterion.
7. Write `report.html` with one section per step.
8. Write `report.md` with the exact heading `## 🧪 QA — PASS ✅` or `## 🧪 QA — FAIL ❌`, one entry per verified flow, failure details, and `**Could not verify:**`.
9. Before an item goes under `**Could not verify:**`, try it again: re-drive the flow, reach the same screen another way (direct URL, in-app navigation, deep link), wait out async work, and switch browser tool or driver when only the observation channel failed. Note what each attempt produced. Keep the limitation only where the retry failed the same way or the blocker is real — missing credentials or account, absent service, unavailable design link — and say which it was.

Use screenshot names `NNN-name.png`. Reference them from `report.md` with relative paths. Keep URLs as inline code. Keep all artifacts under the directory printed by `qa-session`.

Report each flow's verdict, evidence, failures with repro steps, and anything not verified.
