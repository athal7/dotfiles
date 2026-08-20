---
name: qa-verification
description: Fires when verifying a change by driving a running app in a browser — session artifact naming, evidence capture, and the report.md contract other tooling reads. Load this whether you're the dispatched QA persona, an ad-hoc browser-verification task, or the lead doing it directly.
license: MIT
---

Drive the running app with the native `browser` tool; open the app, observe the accessible surface, perform the affected flow, and capture screenshots as evidence. Never read markup or reason about code instead. Read-only re: code — never edit, that routes back to build.

## Steps

1. **Find the app.** Port via `source .envrc && echo $PORT`, else 3000. Confirm the server responds before any browser action. Not running → report and stop, don't guess.
2. **Identify affected flows** from the dispatch. Check the project AGENTS.md for selectors and credentials.
3. **Check for a linked Figma design** — PR description first (`gh pr view --json body -q .body`) for a `figma.com/design|file` URL, then the dispatch focus. Found one → visual fidelity becomes an acceptance dimension: pull the reference frame via the `figma-desktop` MCP and compare layout, spacing, and copy against the live UI. Save the export alongside your screenshots as `00X-figma-reference.png`.
4. **Capture evidence as you go** (below).
5. **Map every piece of evidence to an acceptance criterion** — in your return message and in `report.md`. Design findings map to the AC of the flow they verify.
6. **Report pass/fail with specifics**, including the design verdict when a design was checked.

## Session audit trail

```bash
SESSION_DIR="$HOME/.local/share/qa/$(basename "$PWD")/qa-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

After **every** browser action: scroll into view (`evaluate_script` with `(el) => el.scrollIntoView({block:'center'})`, or `() => window.scrollTo(0,0)` for a page shot), screenshot to `$SESSION_DIR/NNN-slug.png` (sequential, `001-`, `002-`, …), capture the URL via `() => location.href`. Record console errors when they appear.

Write `$SESSION_DIR/report.html` — a self-contained local page, one section per step: screenshot, short title, one-line description, the page URL. Close it out and `open` it when testing is done.

## `report.md`

Alongside the HTML, same session dir:

- Heading `## 🧪 QA — PASS ✅` or `## 🧪 QA — FAIL ❌`. **Never rename it** — the verdict is parsed from this exact string.
- Per verified flow, the acceptance criterion it covers.
- Failure and final-state screenshots inline as **relative** refs `![caption](NNN-name.png)`; step-by-step in a collapsed `<details>` (blank line after `</summary>` or the inner Markdown won't render).
- Page URLs as inline code, never links — they're local and non-navigable.
- A `**Could not verify:**` line, or `none`.

**The store contract is load-bearing.** `report.html`, the `NNN-name.png` names, the `~/.local/share/qa/<project>/qa-<ts>/` path, and `report.md`'s heading are read by the demo command and pruned by the cleanup job. Don't rename or relocate them. Whoever publishes remotely (see `qa-report-publish`) writes `qa-report.html`/`qa-report.md` into the same dir — distinct prefix, no collision. Never write to the remote from here.

## Output

Verdict per flow (not "looks fine"). Flows exercised and states confirmed, with screenshot refs. Failures with exact repro steps, expected vs. observed, URL, console errors — a failure without repro steps isn't actionable. What you couldn't reach, and why. The `$SESSION_DIR` path.
