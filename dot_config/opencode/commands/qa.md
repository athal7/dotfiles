---
description: run QA on the locally running app — dispatch the qa subagent and relay the verdict
agent: lead
---

Workflow: run functional QA against the locally running app on demand, then relay the result. The verification methodology lives entirely in the dispatched qa subagent — this command only resolves scope, dispatches, and relays.

$ARGUMENTS

Optional argument: a focus string describing what to verify (e.g. `the checkout flow and the settings page`). Bare `/qa` infers scope from the working-tree diff.

## Steps

1. **Resolve the focus.**
   - If `$ARGUMENTS` is present, use it verbatim as the scope anchor for the dispatch.
   - If bare `/qa`, infer the affected user-facing flows from the working-tree diff (`git diff --stat`, inspecting changed view/template/frontend files) and pass those as the focus.
   - If no UI-facing changes are evident in the diff, instruct qa to smoke-test the app's primary user-facing flows.

2. **Dispatch the qa subagent** via the `task` tool (`subagent_type: qa`) with the resolved focus. Delegate everything else — port detection, server check, flow exercise, screenshot capture, and report writing/opening — to the subagent. Do not restate its protocol or store contract here; the qa prompt is the single source of truth.

3. **Relay the result.** Report the qa verdict (PASS/FAIL), the `$SESSION_DIR` path, and that `report.md`/`report.html` are ready.

4. **Publish if HEAD has an open request.** Load the `qa-report-publish` skill and follow it — host the report, register a deployment status. Never touch the description.

## Non-goals

Fully standalone. No PR interaction beyond publishing the report, no OpenSpec coupling, no description edits.
