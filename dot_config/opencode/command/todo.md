---
description: Add item(s) to the todo list without interrupting current work
---

Add the specified item(s) to your todo list. Do NOT stop or change what you're currently working on.

**Items to add:** $ARGUMENTS

## Instructions

1. Use `TodoWrite` to add the new item(s) with status `pending`
2. Briefly acknowledge what was added (one line)
3. **Continue exactly where you left off** - do not context switch

## Example

User: `/todo also check the error handling in the auth module`

Response:
- Add "Check error handling in auth module" to todos as pending
- Say: "Added: Check error handling in auth module"
- Resume previous work immediately
