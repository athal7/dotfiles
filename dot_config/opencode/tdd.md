# TDD — strict red/green/refactor

**Every code change follows the full red/green/refactor loop. No exceptions.** New functionality, bug fixes, refactors, review-driven fixes — all of it.

## The inner loop

1. **Red — write a failing test first.** Run it; confirm a meaningful failure. A test that passes before implementation exists is wrong — delete it and write a better one.
2. **Green — minimum code to pass.** No extra features, no speculative code. Run the test, confirm green.
3. **Refactor — improve structure under green tests.** Improve naming, remove duplication, tighten interfaces. Re-run tests after each change. Do not add new behavior during refactor.

Commit when a *meaningful unit of behavior* is complete and refactored — not after every cycle. A meaningful unit is something that would still make sense as a single line in a changelog. Several red/green/refactor cycles often roll into one commit.

## The outer loop — outside-in

For non-trivial behavior, drive from the outside in. Start at the highest level the change is observable from, then drop down as needed:

1. **Outer test (functional / system / integration / acceptance).** Asserts the user-visible behavior. Will stay red while you build out the inner pieces.
2. **Inner unit tests.** Each one drives a small piece of implementation. Each follows its own red/green/refactor.
3. **Outer test eventually goes green.** That's when the feature is done. Refactor across both layers under green.

Outer test still red after several inner cycles is fine and expected. Don't delete it to "make progress" — it's the contract.

## Minimum-to-pass — keep yourself honest

The "keyboard swap" rule from pairing: when a test goes green, ask "could the simplest hardcoded answer pass this?" If yes, the test isn't strong enough yet — write another test that forces real implementation.

Three escalating tactics for minimum-to-pass:

| Tactic | When | Example |
|---|---|---|
| **Fake it** | First test, no implementation exists | `return 42` (literal expected value). Forces the next test to invalidate the constant. |
| **Triangulate** | Constant passes; need to drive variation | Add a second test with different inputs, forcing real logic. |
| **Obvious implementation** | The general solution is small and clear | Skip fake-it; write the real thing directly. Use sparingly — easy to over-implement. |

Fake-it isn't lazy; it's the contract that proves the *test* is real. If your test passes the moment you write it, you've written a performative test, not a behavioral one.

## What a good test looks like

**Name describes the behavior, not the implementation.** `it_returns_404_when_user_not_found`, not `test_get_user_returns_error`. The name should read as a sentence about the system's contract.

**Arrange / Act / Assert structure.** One block sets up state, one block exercises the behavior, one block asserts the outcome. Visible separation; reviewers find each phase fast.

**One behavior per test.** Multiple assertions are fine if they describe one behavior. Multiple unrelated assertions in one test means it's two tests.

**Failure messages explain what went wrong.** `expect(result).to eq(42)` is fine — frameworks usually generate "expected 42, got X" automatically. Custom matchers help when the diff isn't obvious.

**Tests fail for one reason.** If a test breaks, you should know exactly which line of production code is wrong. If breaking the test could mean ten different things, split it.

## Test strategy — what cases to cover

For any new behavior, write tests across these axes — usually 3-5 tests, not 20:

| Case type | What to cover |
|---|---|
| **Happy path** | The expected, normal use. The contract in its simplest form. |
| **Edge cases** | Boundaries — empty, null, zero, one, max. The values where logic flips. |
| **Error cases** | Bad inputs, missing dependencies, expected failures. Not exception-throwing for its own sake — the *contract* for failure. |
| **Regression** | Past bugs. Each bug fix gets a test that would have caught it. |

Skip cases when the test wouldn't add information. A getter that returns a field doesn't need an "edge case" — there are no edges.

**Test the behavior the user sees, not the internal data structure.** A test that asserts `cache.entries.size == 1` is fragile — change the cache strategy and the test breaks despite the contract holding. `cache.get('foo') == bar` is durable.

## Failure modes to avoid

| Mistake | Correction |
|---|---|
| Writing implementation before a test | Stop. Delete the implementation. Write the test first. |
| Skipping the red phase ("I know it'll fail") | Not optional. Run it. See the failure. |
| Performative test that passes immediately | The test isn't strong enough. Add a fake-it implementation, prove the test catches it, then triangulate. |
| Test asserts internals (private state, struct shapes) | Rewrite to assert observable behavior. |
| Many assertions in one test | Split — one behavior per test. |
| Outer test deleted "to make progress" | Restore. The outer test is the contract. Keep it red until the feature is done. |
| Committing every red/green | Group cycles into meaningful behavior units. Commit when a changelog entry would make sense. |
| "Just a small change, no test needed" | No change is too small. Write the test. |

## Bug fixes and refactors

- **Bug fix:** write a test that reproduces the bug — it should fail in the current code. Then fix, see green. The reproduction test stays in the suite forever.
- **Refactor:** existing tests are your safety net. If they don't cover the area you're refactoring, write them first, get them green on current code, then refactor under green.
- **Review-driven fix:** the reviewer pointed at a behavior. Write the test that asserts the desired behavior — it should fail. Then fix.

If you're touching source code without a test in hand, you're not doing TDD. Stop and write the test.

## Resuming mid-session

If TDD discipline has slipped:

1. Stop current work.
2. Identify implementation that exists without a corresponding failing test.
3. Write the missing test(s), confirm they pass (they should, since implementation exists).
4. You can't go back to red for existing code — document the gap and continue strict TDD forward.

## Checkpoint format

After a meaningful unit of behavior, note:
```
Outer: <acceptance test name> — red / green
Inner cycles: <count>
Behavior: <what the user can now do>
Tests added: <names>
Refactor: <what got cleaned up, or "none">
Committed: <sha + message>
```
