---
description: Review changes [commit|branch|pr], defaults to uncommitted
agent: review
---

Review code changes for bugs, security issues, and quality concerns.

**Input:** $ARGUMENTS

## Workspace Detection

Before reviewing, ensure you're in the correct git repository:

1. **Get git root and branch**:
   ```bash
   git rev-parse --show-toplevel
   git branch --show-current
   ```

2. **Verify context makes sense**:
   - If on `main`/`master` with no uncommitted changes, you're likely in the wrong directory
   - Search workspace locations for a feature branch:
     - Git worktrees: `git worktree list`
     - Opencode workspaces: `ls ~/.local/share/opencode/worktree/*/ ~/.local/share/opencode/clone/*/`
   - Identify and use the workspace with the expected feature branch

**Do not ask the user which directory to use** - find it automatically.

## Determining What to Review

Based on input, determine review type:

1. **No arguments (default)**: Review changes on current branch
   - First check: `git diff` and `git diff --cached`
   - If no uncommitted changes: `git diff origin/<default>...HEAD`
   - If both empty: report "No changes to review"

2. **Commit hash** (SHA): `git show $ARGUMENTS`

3. **Branch name**: `git diff $ARGUMENTS...HEAD`

4. **PR URL or number**: 
   - `gh pr view $ARGUMENTS` for context
   - `gh pr diff $ARGUMENTS` for diff

## Review Process

1. Get the diff using appropriate method above
2. Identify which files changed
3. Read full files to understand context (not just diff)
4. Check for CONVENTIONS.md, AGENTS.md in the workspace
5. Apply review criteria and produce findings
