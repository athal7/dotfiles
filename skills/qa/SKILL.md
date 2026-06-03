---
name: qa
description: QA verification with Firefox DevTools browser automation — load when a diff touches UI, views, or user-facing flows and needs functional verification before committing
license: MIT
compatibility: opencode
---

Perform QA verification using Firefox DevTools browser automation.

## Setup

1. **Read issue context** — check `openspec/changes/` for an active change proposal, or `.opencode/context-log.md` if no OpenSpec change exists. Look for acceptance criteria and components to test.
2. **Detect Port** — Run `source .envrc && echo $PORT`, fall back to 3000
3. **Verify Server** — curl localhost:PORT before browser automation
4. **If server not running** — Report clearly and stop

## Session Audit Trail

At the start of every run, create the session directory and initialize the report:

```bash
SESSION_DIR="$HOME/.local/share/qa/$(basename "$PWD")/qa-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$SESSION_DIR"
cat > "$SESSION_DIR/report.html" <<'HEADER'
<html><head><style>body{font-family:system-ui,sans-serif;max-width:1100px;margin:2em auto;padding:0 1em}.step{display:flex;gap:1.5em;margin:2em 0;align-items:start}.step img{width:55%;border:1px solid #ccc;border-radius:4px;flex-shrink:0}.step .info{padding-top:.25em}.step .info h3{margin:0 0 .5em}.step .info p{margin:0 0 .5em;color:#333}.step .info a{color:#0969da;word-break:break-all}</style></head><body>
HEADER
```

Reports persist per-project under `~/.local/share/qa/` so they can be referenced later (e.g. by the demo command).

After **every** browser action (navigate, click, fill, submit), scroll then screenshot:

- Interacted with a specific element → `evaluate_script` with `(el) => el.scrollIntoView({ block: 'center' })`, passing the element's UID as an arg
- General page-state shot → `evaluate_script` with `() => window.scrollTo(0, 0)`

Save the screenshot, then capture the page URL via `evaluate_script` with `() => location.href`, then append a report section:

```
screenshot_page saveTo="$SESSION_DIR/001-page-name.png"
```

```bash
cat >> "$SESSION_DIR/report.html" <<STEP
<div class="step">
  <img src="001-page-name.png">
  <div class="info">
    <h3>Short step title</h3>
    <p>One-line description of what was verified or happened.</p>
    <p><a href="THE_URL">THE_URL</a></p>
  </div>
</div>
STEP
```

Number files sequentially (`001-`, `002-`, …). Use a short descriptive slug. Substitute the actual step title, description, filename, and captured URL into each section.

After all testing is done, close and open the report:

```bash
printf '</body></html>' >> "$SESSION_DIR/report.html" && open "$SESSION_DIR/report.html"
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
2. Session directory path (e.g. `~/.local/share/qa/<project>/qa-20260515-143022/`)
3. HTML report opened for inspection (all screenshots in sequence)
4. Steps to reproduce failures
