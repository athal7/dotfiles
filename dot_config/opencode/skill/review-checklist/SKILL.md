---
name: review-checklist
description: Code review checklist - security, correctness, performance, maintainability
---

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

## Unused Code Detection

Before flagging, **read call sites** to verify:

- New functions/methods not called anywhere
- New exports not imported elsewhere
- New parameters not used in function body
- New variables assigned but never read

## Minimize Diff (own code only)

- Unnecessary whitespace/formatting changes
- Unrelated refactors (separate PR)
- Changes to files not needed for feature
