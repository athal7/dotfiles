---
name: tdd
description: Strict red/green/refactor loop — load before any source-code edit. Applies to new features, bug fixes, refactors, and review-driven fixes alike. Write the failing test first, every time.
license: MIT
compatibility: opencode
metadata:
  provides:
    - tdd
---

# Skill: TDD (Strict)

## Rule

**Every code change follows the full red/green/refactor loop. No exceptions.** This applies each time new functionality is written or existing behavior is changed, regardless of how far into a session we are.

## The Loop

### 1. Red — Write a failing test first

- Write the test before any implementation exists
- Run the test and **confirm it fails** with a meaningful error
- A test that passes before implementation is wrong — delete it and write a better one
- Do not proceed to Green until you have seen a red failure

### 2. Green — Minimal implementation

- Write the minimum code required to make the test pass
- Nothing more — no extra features, no speculative code
- Run the test and confirm it is green

### 3. Refactor — Clean up

- Improve structure, naming, duplication while keeping tests green
- Re-run tests after every refactor change
- Do not add new behavior during refactor

### 4. Commit

- Commit after each green/refactor cycle
- Commit message should reflect the behavior added, not the mechanics

## Failure Modes to Avoid

| Mistake | Correction |
|---------|-----------|
| Writing implementation before a test | Stop. Delete the implementation. Write the test first. |
| Skipping the red phase ("I know it'll fail") | Not optional. Run it. See the failure. |
| Writing multiple features before committing | One cycle at a time. Commit after each green. |
| "Just a small change, no test needed" | No change is too small. Write the test. |

## Bug Fixes and Refactors

TDD isn't only for new features. The same loop applies:

- **Bug fix:** write a test that reproduces the bug — it should fail in the current code. Then fix, see green. The reproduction test stays in the suite.
- **Refactor:** the existing tests are your safety net. If they don't cover the area you're refactoring, write them *first* (red where appropriate), get them green on current code, then refactor under green.
- **Review-driven fix:** the reviewer pointed at a behavior. Write the test that asserts the desired behavior — it should fail. Then fix.

If you're touching source code without a test in hand, you're not doing TDD. Stop and write the test.

## Resuming Mid-Session

If TDD discipline has slipped during the session:

1. Stop current work
2. Identify what implementation exists without a corresponding failing test
3. Write the missing test(s), confirm they pass (they should, since implementation exists)
4. Note: you cannot go back to red for existing code, but document the gap and continue strict TDD from this point forward

## Checkpoint Format

After each cycle, note:
```
Red: <test name> failed with <error>
Green: <what was implemented>
Refactor: <what was cleaned up, or "none">
Committed: <short sha>
```
