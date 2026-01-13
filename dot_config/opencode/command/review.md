---
description: Review changes [commit|branch|pr], defaults to uncommitted
agent: review
---

Review code changes for bugs, security issues, and quality concerns.

**Input:** $ARGUMENTS

## Workspace Detection

**Default to `$PWD`**, but verify it matches the conversation context.

If the conversation mentions specific PRs, branches, files, or technologies that don't exist in `$PWD`, search for the correct workspace:
- Check `~/.local/share/opencode/worktree/*/` and `~/.local/share/opencode/clone/*/`
- Match based on PR numbers, branch names, or file paths mentioned in conversation
- Use `gh pr view` or `git branch -a` to verify matches

Examples of mismatch:
- Conversation about "PWA changes" and "service workers" but `$PWD` is a dotfiles repo
- Conversation mentions PR #7258 but `$PWD` repo has no such PR
- Conversation references `prompt-input.tsx` but no such file in `$PWD`

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
