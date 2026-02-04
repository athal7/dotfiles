---
description: Review changes [commit|branch|pr], defaults to uncommitted
tools:
  context7_*: true
skills:
  - review-checklist
  - gh-pr-inline
---

Review code changes for bugs, security issues, and quality concerns.

**Input:** $ARGUMENTS

## Context Gathering

**Before reviewing, read `.opencode/context-log.md`** for issue context and build history.

**Diffs alone are not enough.** After getting the diff:
- Read entire modified file(s) to understand full context
- Check for CONVENTIONS.md, AGENTS.md in the workspace

## Determining What to Review

Based on input:

1. **No arguments**: `git diff` + `git diff --cached`, then `git diff origin/<default>...HEAD`
2. **Commit hash**: `git show $ARGUMENTS`
3. **Branch name**: `git diff $ARGUMENTS...HEAD`
4. **PR URL/number**: `gh pr view`, `gh pr diff`, `gh pr checkout`

## Review Process

1. Get diff using appropriate method above
2. Read full files for context (not just changed lines)
3. Apply `review-checklist` skill criteria
4. **Be certain** - only flag bugs you're confident about
5. Investigate before flagging; read more files if uncertain

## Style

- Use "I" statements: "If it were me...", "I wonder if..."
- Frame as questions, not directives
- Keep comments short and focused
- **No flattery** - no "strengths" sections

## Output Format

**Local reviews** (uncommitted, commits, branches):

```markdown
## Summary
[One line description]

## Issues Found

### path/to/file.rb:10
[Issue description]

## Recommendation
[Approve / Request changes / Comment]
```

**PR reviews**: Use `gh-pr-inline` skill for posting format. Always show proposed comments and wait for approval before posting.

## Learnings Check

If session involved debugging breakthroughs or non-obvious discoveries, suggest `/learn`.
