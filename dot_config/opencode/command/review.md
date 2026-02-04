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

**Be terse.** Developers can read code—don't explain what the diff does.

```markdown
## Verdict: [APPROVE | CHANGES REQUESTED | COMMENT]

[One sentence why, if not obvious]

## Blockers

- **file.rb:10** - [2-5 word issue]. [1 sentence context if needed]

## Suggestions (non-blocking)

- **file.rb:25** - [2-5 word suggestion]

## Nits

- **file.rb:30** - [tiny thing]
```

**Rules:**
- Skip sections with no items (don't say "None")
- Max 1-2 sentences per item
- No "Good job" / "Looks good" filler
- Don't narrate obvious changes ("adds a new function that...")
- Use code snippets only if fix is non-obvious

**For PR reviews**, add a brief TL;DR at the top summarizing what the PR does (1-2 sentences).

**PR reviews**: Use `gh-pr-inline` skill for posting format. Always show proposed comments and wait for approval before posting.

## Learnings Check

If session involved debugging breakthroughs or non-obvious discoveries, suggest `/learn`.
