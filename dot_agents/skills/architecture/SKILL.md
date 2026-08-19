---
name: architecture
description: Load before designing a new system, choosing between competing implementations, weighing tradeoffs across libraries or frameworks, or escalating an architectural question to a human. Fires at the moment a multi-option design decision appears, not during routine implementation.
license: MIT
---
Load `code-quality` before applying this framework.


## Check for a prerequisite refactor first

For any change touching domain logic, authorization, state machines, or anything enforced in more than one layer — read the code and answer:

- Already checked in multiple places? List the callsites. Centralizing first may be the prerequisite.
- New dependency between modules that had no prior relationship?
- 2nd or 3rd instance of a pattern? One abstraction may serve all of them.

Found one → propose it as a separate issue/PR, get confirmation, do it first.

## Present options, don't decide alone

Always 2+ options in a table (what it is / pros / cons / best when). One option presented as fait accompli is a failure.

Score on: reversibility, YAGNI, simplicity, testability, coupling, operational cost, DX. **When criteria conflict, prefer reversibility and simplicity — complexity must earn its place.**

Recommend with one sentence naming the single most important reason.

## Escalate instead of recommending

- Irreversible at the data layer (schema, migration strategy)
- Crosses service or team boundaries
- Real operational cost — new infrastructure, new external dependency
- You're genuinely uncertain after applying the framework
