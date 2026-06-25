---
description: Move the current session into a new git worktree, creating it
agent: general
---

Move THIS session into a new git worktree.

$ARGUMENTS

## Steps
1. Determine the branch name: if `$ARGUMENTS` is non-empty, use it as the branch name. Otherwise, choose a short, descriptive, kebab-case branch name based on the work this session has been doing.
2. Call the `move_to_worktree` tool with that branch name. Do not ask for confirmation.
3. Reply with only the new worktree path returned by the tool.
