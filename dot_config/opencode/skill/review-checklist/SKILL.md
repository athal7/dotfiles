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
- Inverse operations are symmetric (create/destroy, archive/unarchive fully reverse each other)
- UI-indicated requirements (e.g. `*` on labels) enforced server-side
- No unnecessary indirection (wrapping single values in arrays, passing locals already in scope)

## Performance

- No N+1 queries (check loops with DB calls)
- No over-fetching: eager-loads only pull associations the action actually uses
- Broad loading scopes applied per-action, not blanket per-controller
- Indexes exist for filtered/sorted columns
- No O(n^2) on unbounded data
- Large lists paginated or virtualized

## Maintainability

- Functions do one thing
- Names are precise (not `data`, `info`, `handle`)
- No dead code or debug logging
- Test coverage for changed code, at the right tier (don't use slow browser tests for things fast tests cover)

## DRY / Reuse

- New views/templates: does a similar one already exist? Extend it rather than duplicating.
- New controllers/services: check for existing patterns that can be shared via extraction.
- Duplicated markup/logic will drift — flag the risk.

## Side Effects

- Trace the callback/job chain: does this trigger emails, notifications, webhooks?
- Side effects should fire after the operation succeeds, not before
- Guard clauses and early returns belong at the top

## Behavior Changes

- Flag any behavioral change (especially if possibly unintentional)
- Changed defaults, reordered operations, modified return values
- API contract changes (new required params, changed response shape)

## API Completeness (when adding/modifying APIs)

- Field parity with existing API (check for missing fields, filters, arguments)
- Response examples in documentation
- Breaking changes flagged explicitly

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
- Changes to files outside the feature's domain — ask why

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
