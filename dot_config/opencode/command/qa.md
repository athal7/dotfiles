---
description: QA verification using browser automation
agent: qa
---

Perform QA verification of a localhost workflow using Playwright browser automation.

**Request:** $ARGUMENTS

## Setup

1. **Detect Port** - Check `.envrc` for `PORT=`, fall back to 3000
2. **Verify Server** - Confirm localhost is responding before starting

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
- **Iterate silently** - If something fails, retry with adjusted approach before reporting
