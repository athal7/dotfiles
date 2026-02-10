---
description: QA verification using browser automation
---

Perform QA verification using Playwright browser automation.

**Request:** $ARGUMENTS

## Setup

1. **Read `.opencode/context-log.md`** for issue context, acceptance criteria, and components to test
2. **Detect Port** — Run `source .envrc && echo $PORT`, fall back to 3000
3. **Verify Server** — curl localhost:PORT before browser automation
4. **If server not running** — Report clearly and stop

## Verification

1. **Happy path first**: Verify the main flow works
2. **Edge cases**: Empty states, errors, boundaries
3. **Visual check**: Screenshot key states
4. **Accessibility**: Tab navigation, focus states

Use Playwright MCP tools. Check project AGENTS.md for selectors/credentials.

## Resilience

- Element not found → try alternative selectors, wait longer, scroll into view
- Timeout → increase wait time, check if page is still loading
- Try at least 3 approaches before giving up
- When truly blocked: report what was verified, what failed, and why

## Output

1. Pass/fail summary with issues found
2. Screenshots of key states
3. Steps to reproduce failures
