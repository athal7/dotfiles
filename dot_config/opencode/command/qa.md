---
description: QA verification using browser automation
tools:
  playwright_*: true
---

Perform QA verification using Playwright browser automation.

**Request:** $ARGUMENTS

## Context Gathering

**Before testing, read `.opencode/context-log.md`** which contains:
- Issue context and acceptance criteria
- Components modified (focus testing there)
- Known risks and edge cases to verify

## Setup

1. **Detect Port** - Run `source .envrc && echo $PORT` to get the actual port. Fall back to 3000 if that fails.
2. **Verify Server** - Use curl to confirm localhost:PORT is responding before browser automation
3. **If server not running** - Report clearly and stop (don't attempt browser automation)

## Verification Approach

1. **Happy path first**: Verify the main flow works
2. **Edge cases**: Empty states, errors, boundaries
3. **Visual check**: Screenshot key states
4. **Accessibility**: Tab navigation, focus states

## Playwright Tools

Use the Playwright MCP tools to:
- Navigate to pages
- Interact with elements (click, type, select)
- Take screenshots at key states
- Evaluate page state
- Wait for conditions

## Resilience

**Persist through transient failures:**
- Element not found → try alternative selectors, wait longer, scroll into view
- Timeout → increase wait time, check if page is still loading
- Click failed → ensure element is visible and not covered
- Try at least 3 different approaches before giving up on any single action

**When truly blocked (after multiple attempts):**
1. Report what you were able to verify
2. Explain what you tried and why it failed
3. Suggest what might fix it (missing element, wrong URL, server not running)

## Output

1. Pass/fail summary with any issues found
2. Screenshots saved showing key states
3. Steps to reproduce any failures

## Rules

- **Check project AGENTS.md first** - Use selectors/credentials documented there
- **One flow per QA run** - Keep verification focused
- **Screenshot key moments** - Before/after states
