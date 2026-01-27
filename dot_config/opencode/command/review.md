---
description: Review changes [commit|branch|pr], defaults to uncommitted
tools:
  context7_*: true
---

Review code changes for bugs, security issues, and quality concerns.

**Input:** $ARGUMENTS

## Context Gathering

**Before reviewing, read `.opencode/context-log.md`** which contains:
- Issue context and acceptance criteria
- Build narrative (how the code evolved)
- Test signals (what passed/failed at each step)

**Diffs alone are not enough.** After getting the diff:
- Read the entire file(s) being modified to understand full context
- Code that looks wrong in isolation may be correct given surrounding logic
- Check for CONVENTIONS.md, AGENTS.md in the workspace

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
   - `gh pr checkout $ARGUMENTS` to read actual files

## Review Priorities

1. **Correctness** - Does it work? Are there bugs?
2. **Security** - Auth/authz, injection, secrets, state integrity
3. **Performance** - N+1, indexes, O(n²) on unbounded data
4. **Maintainability** - Readability, testability, simplicity

## What to Check

**Security** (auth/*, api/*, *token*, *.env*):
- No secrets in code
- Input validation present
- Auth checks on protected routes

**Quality**:
- Test coverage for changed code
- Dead code, debug logging removed
- Functions doing one thing
- Precise naming

## Before Flagging

**Be certain.** Only flag bugs you're confident about.

- Only review changes, not pre-existing code
- Investigate before flagging as bug
- Don't invent hypothetical problems
- If uncertain, read more files first

## Style

- Use "I" statements: "If it were me...", "I wonder if..."
- Frame as questions, not directives
- Keep comments short and focused
- **No flattery** - No "strengths" sections, no praise

## Output Format

```markdown
## Summary
[One line description of what changed]

## Issues Found

### path/to/file.rb:10
[Issue description]

```suggestion
suggested fix if applicable
```

## Recommendation
[Approve / Request changes / Comment]
```

**Line numbers must be from actual files** (use Read tool), not from diff positions.
