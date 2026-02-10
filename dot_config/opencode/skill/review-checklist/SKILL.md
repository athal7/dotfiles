---
name: review-checklist
description: Code review checklist - security, correctness, performance, maintainability
---

## Context Gathering

**Read `.opencode/context-log.md`** first for issue context and build history.

**Extract issue IDs** from branch name or PR, then fetch details:
1. `git branch --show-current` — parse for `ENG-123`, `PROJ-456`, `#123`, `gh-123`
2. For PRs: check PR body and linked issues via `gh pr view --json body,title`
3. Fetch: Linear → `team-context_get_issue`, GitHub → `gh issue view`

**Use context to verify:** requirements alignment, acceptance criteria, scope creep, project goals.

**After getting the diff:** read entire modified file(s) for full context. Check for CONVENTIONS.md, AGENTS.md.

## Security (auth/*, api/*, *token*, *.env*)

- No secrets in code
- Input validation present
- Auth checks on protected routes
- SQL/NoSQL injection prevention
- XSS prevention for user input rendering

## Correctness

- Edge cases handled (null, empty, boundary values)
- Error states have clear user feedback
- Async operations have proper error handling
- State mutations are intentional

## Performance

- No N+1 queries (check loops with DB calls)
- Indexes exist for filtered/sorted columns
- No O(n^2) on unbounded data
- Large lists paginated or virtualized

## Maintainability

- Functions do one thing
- Names are precise (not `data`, `info`, `handle`)
- No dead code or debug logging
- Test coverage for changed code

## Behavior Changes

- Flag any behavioral change (especially if possibly unintentional)
- Changed defaults, reordered operations, modified return values
- API contract changes (new required params, changed response shape)

## Unused Code Detection

Before flagging, **read call sites** to verify:

- New functions/methods not called anywhere
- New exports not imported elsewhere
- New parameters not used in function body
- New variables assigned but never read

## Style Tolerance

Before flagging style issues:
- Verify the code is *actually* in violation
- Some "violations" are acceptable when they're the simplest option
- Don't flag style preferences unless they clearly violate established project conventions

## Minimize Diff (own code only)

- Unnecessary whitespace/formatting changes
- Unrelated refactors (separate PR)
- Changes to files not needed for feature

## Output Format

**Be terse.** Developers can read code — don't explain what the diff does.

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
- Max 1-2 sentences per item. No filler.
- Use code snippets only if fix is non-obvious
- Use "I" statements, frame as questions not directives

**For PRs:** add TL;DR at top. If issue context found, add Requirements Check after verdict.
