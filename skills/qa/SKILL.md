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
2. Screenshots of key states
3. Steps to reproduce failures
