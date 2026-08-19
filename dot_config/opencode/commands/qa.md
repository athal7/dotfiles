---
description: run QA on the locally running app — dispatch the qa agent and relay the verdict
agent: lead
---

Workflow: functional QA against the locally running app, then relay the result. The methodology lives entirely in the `qa` agent — resolve scope, dispatch, relay.

$ARGUMENTS

Optional argument: a focus string (e.g. `the checkout flow and the settings page`). Bare invocation infers scope from the working-tree diff.

## Steps

1. **Resolve the focus.** Argument present → use it verbatim. Bare → infer affected user-facing flows from the working-tree diff (`git diff --stat`, inspecting changed view/template/frontend files). No UI-facing changes evident → have qa smoke-test the app's primary flows.
2. **Dispatch `qa`** with the resolved focus. Delegate everything else — port detection, server check, flow exercise, screenshots, report writing. Don't restate its protocol or store contract; the qa prompt owns those.
3. **Relay** the verdict, the `$SESSION_DIR` path, and that `report.md`/`report.html` are ready.
4. **Publish if HEAD has an open request.** Load `qa-report-publish` — host the report, register a deployment status. Never touch the description.

## Non-goals

Standalone. No request interaction beyond publishing the report or description edits.
