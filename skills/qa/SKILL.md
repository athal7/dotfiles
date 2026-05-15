---
name: qa
description: QA verification with Firefox DevTools browser automation — load when a diff touches UI, views, or user-facing flows and needs functional verification before committing
license: MIT
compatibility: opencode
metadata:
  provides:
    - qa
---

Perform QA verification using Firefox DevTools browser automation.

## Setup

1. **Read `.opencode/context-log.md`** for issue context, acceptance criteria, and components to test
2. **Detect Port** — Run `source .envrc && echo $PORT`, fall back to 3000
3. **Verify Server** — curl localhost:PORT before browser automation
4. **If server not running** — Report clearly and stop

## Session Audit Trail

At the start of every run:

```bash
SESSION_DIR="/tmp/qa-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
```

After **every** browser action (navigate, click, fill, submit), scroll then screenshot:

- Interacted with a specific element → `evaluate_script` with `(el) => el.scrollIntoView({ block: 'center' })`, passing the element's UID as an arg
- General page-state shot → `evaluate_script` with `() => window.scrollTo(0, 0)`

Then save the screenshot:

```
screenshot_page saveTo="$SESSION_DIR/001-page-name.png"
```

Number files sequentially (`001-`, `002-`, …). Use a short descriptive slug as the name.

After all testing is done, generate and open the HTML report:

```bash
(cd "$SESSION_DIR" && printf '<html><body style="font-family:sans-serif">' > report.html && for f in *.png; do printf '<figure style="margin:2em 0"><img src="%s" style="max-width:100%%;border:1px solid #ccc"><figcaption>%s</figcaption></figure>\n' "$f" "$f" >> report.html; done && printf '</body></html>' >> report.html && open report.html)
```

## Verification

Use firefox-devtools MCP tools. Check project AGENTS.md for selectors/credentials.

Verify the main flow, then edge cases (empty states, errors, boundaries). Screenshot key states. Check tab navigation and focus for accessibility.

## Resilience

- Element not found → try alternative selectors, wait longer, scroll into view
- Timeout → increase wait time, check if page is still loading
- Try at least 3 approaches before giving up
- When truly blocked: report what was verified, what failed, and why

## Output

1. Pass/fail summary with issues found
2. Session directory path (e.g. `/tmp/qa-20260515-143022/`)
3. HTML report opened for inspection (all screenshots in sequence)
4. Steps to reproduce failures
