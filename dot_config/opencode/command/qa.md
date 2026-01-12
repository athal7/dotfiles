---
description: QA verification using browser automation
agent: qa
---

Perform QA verification of a localhost workflow using Playwright browser automation.

**Request:** $ARGUMENTS

## Setup

1. **Detect Port** - Run `source .envrc && echo $PORT` to get the actual port (handles dynamic calculation). Fall back to 3000 if that fails.
2. **Verify Server** - Use curl to confirm localhost:PORT is responding before starting browser automation
3. **If server not running** - Report this clearly and stop (don't attempt browser automation)

## Verification

Use the Playwright MCP tools to:
1. Navigate to the relevant pages
2. Perform the user flow being tested
3. Take screenshots at key states
4. Verify expected behavior with assertions

## Output

1. Pass/fail summary with any issues found
2. Screenshots saved showing key states
3. Steps to reproduce any failures

## Rules

- **Check AGENTS.local.md first** - Use selectors/credentials documented there
- **One flow per QA run** - Keep verification focused
- **Screenshot key moments** - Before/after states
- **Persist through failures** - If a selector fails, try alternative approaches (different selectors, waiting longer, scrolling into view). Only give up after 3+ attempts with different strategies.
- **Report actionable feedback** - If blocked, explain what you tried and suggest what might fix it
