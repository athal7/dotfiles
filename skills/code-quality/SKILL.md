---
name: code-quality
description: Load when reviewing a diff, naming a code smell or anti-pattern, deciding refactoring direction, or grading review-comment severity. Required reading when a named pattern is cited — load explicitly rather than paraphrasing from memory.
license: MIT
---

Reference content for naming and addressing structural and hygiene problems in code. Consumers cite the relevant pattern or rule by name.

## Discipline

When citing any pattern or rule from this catalog:

- **Name** the pattern (e.g. "Feature Envy", "Premature Abstraction"); cite Fowler or Evans where applicable.
- **Refactoring direction** — propose a concrete move (e.g. "Move Method to X", "Replace Conditional with Polymorphism", "Extract Policy object").
- **Severity** — `blocker` if the change entrenches a pre-existing scattered pattern by adding a callsite; `suggestion` if it introduces a new pattern or a prerequisite refactor would simplify the work.

## Pre-existing pattern rule

**"Make the change easy, then make the easy change."** — Kent Beck. When working with code that has pre-existing problems:

- **Doesn't worsen it** (reads, passes through, no new callsite): skip — never flag ambient patterns the work doesn't interact with.
- **Adds another callsite** to a scattered pattern: flag as **blocker** — stop and extract.
- **Depends on it** (would be simpler if fixed first): flag as **suggestion** — "Consider extracting [X] first as a prerequisite." Suggest a separate issue.

---

## System-level anti-patterns

For evaluating a *proposed approach* before code exists.

- **Premature abstraction** — interface/layer before 2+ concrete implementations.
- **Wrong layer** — business logic in DB, presentation in service layer, persistence in domain.
- **Leaky abstraction** — forces callers to know its internals.
- **Distributed monolith** — services that must deploy together or share a database.
- **Config as code** — logic that belongs in code lives in feature flags or env vars.
- **Speculative generality** — building for scale or flexibility not needed yet.

## Code-level smells

For scanning a *concrete diff* for structural problems.

### Tell, Don't Ask / Feature Envy

Callsites pulling state out of an object to make a decision the object should make itself.

Signals: multiple files checking the same attribute chain (`record.status == :locked`, `record.full_lock?`); same conditional duplicated across services/controllers/views/helpers; new method replicating a check already in another layer.

When found: name the violated object, list every callsite, suggest where the logic belongs (policy, model method, service). Adding *another* callsite to an already-scattered pattern is a **blocker**.

### Scattered Enforcement

A specific Tell-Don't-Ask: authorization or validation enforced in multiple places independently. Access decisions in controller AND service AND view; policy methods partially redundant with service-layer guards; lock/state checks in helpers and views duplicating service rules.

Flag: "Enforced in N places — [list]. Any new callsite should go through [central point]."

### Shotgun Surgery

One logical change requires edits across 5+ unrelated files. The rule isn't encapsulated.

### Primitive Obsession / Data Clumps

Primitives passed together repeatedly where a value object would clarify intent. Domain concepts as raw strings or magic numbers. A parameter hash that grows beyond 3-4 keys and always travels together.

### Layering Violations

Business logic in a view or controller. Persistence logic in domain objects (queries in presenters/helpers). View conditionals encoding business rules.

### Anemic Domain Model

Rich service classes doing all the work, model is a data bag. Methods that only do `self.field = value; save`. New service files reconstructing domain knowledge already implicit in the model. Only flag when the diff *adds* to this pattern.

### Anti-Extensibility Conditionals

New `if/elsif/case` on type/state/role where polymorphism or strategy would eliminate future N+1 branching. Existing `case` extended with another arm — flag "this case has N arms now; consider a table or strategy pattern."

### Coupling Introduced

New cross-module dependency where modules had no prior relationship. New parameter threaded through multiple layers. New shared mutable structure (global config, class-level state) creating hidden coupling.

---

## Hygiene rules

For diff review beyond named patterns.

- **Single responsibility** — flag functions/classes doing too many things.
- **Method placement** — method with one call site in a different domain belongs closer to caller.
- **Naming** — flag imprecise (`data`, `info`, `handle`, `process`, `temp`) or domain-opaque (`internal`, `app`, `type`, `status` without qualification).
- **Dead code** — for every new function, method, scope, constant, or route in the diff, search for callers; zero callers = dead.
- **Orphaned code** — for every call the diff REMOVES, check if the target still has other callers; last caller removed = dead.
- **DRY violations** — duplicated logic where existing patterns could be extended. Confirm the pattern exists elsewhere via code search before flagging.
- **UX pattern drift** — different interactions than established patterns on similar pages (inline vs. modal editing, URL-synced vs. non-synced filters).
- **Job granularity** — N individual jobs in a loop where one batch job would work, or vice versa.
- **Propagation** — when the diff renames, removes, or semantically changes a column, attribute, enum, scope, association, route, or method, search the entire codebase (source, views, JS, JSON, YAML, fixtures, exports, serializers, mailers, jobs, seed files, admin pages, marketing pages). Any surviving reference not updated by the diff is a blocker.
- **Caching correctness** — when the diff reads from caches (in-process memoization, Redis, framework cache stores), verify the cached value can't be stale relative to the operation's requirements, especially after writes.
- **Minimize diff** — unnecessary whitespace changes (blank lines added/removed, trailing whitespace, re-indentation), unnecessary formatting changes, unrelated refactors, scope creep.

## Deterministic enforcement

When a finding is an instance of a standing repo convention rather than a one-off — a naming rule, a layering boundary, a banned pattern, or guidance already written down (an `AGENTS.md` / `CONVENTIONS.md` rule, an agent instruction) that keeps getting missed — the durable fix is a deterministic guardrail, not a repeated comment. A rule enforced by tooling (a lint rule, custom static-analysis check, or test) is a fitness function (Ford/Parsons/Kua): continuously verified, not re-applied by memory; a rule enforced only by review commentary has to be manually re-cited every time it comes up. Recommend encoding it as an automated check (a custom lint rule, a test, or a CI gate) so the convention self-enforces. A soft nudge that isn't being followed is the strongest signal — propose replacing it rather than restating it. Once a rule is codified as a deterministic check, stop duplicating it in review commentary — cite the check's failure, not the pattern name, and let the tooling own enforcement. Severity: `suggestion` and a separate follow-up by default; when the convention is already documented and the diff violates it, the finding carries the weight of that documented rule. Surface the candidate — adding the rule is a follow-up, not part of the diff under review.

The **mechanical sweeps** above are the prime fitness-function candidates: **Propagation**, **Dead code**, **Orphaned code**, and **blast-radius** (caller/callee) checks are exactly the kind of exhaustive, automatable scan a deterministic guard should own. Run the manual sweep to catch the immediate instance in the diff, but treat an unguarded one of these as a missing fitness function: recommend the durable check (a test that fails when a reference is left dangling, a lint rule that bans the orphaned symbol, a CI grep gate) rather than relying on a human re-running the sweep every review. Hand-running an automatable scan is the soft nudge that won't scale.

## Tests

- **Test coverage** — every changed behavior has tests. Missing coverage on a happy path or a documented edge case is a finding.
- **Test validity** — stubs/mocks must target methods actually called in the code path being tested. A stub on a method outside the execution path means the test asserts nothing.
- **Testing pyramid** — tests sit at the right tier. Most coverage is unit (fast, isolated, exercises one module). Integration tests are for cross-module contracts. End-to-end tests are sparse, expensive, used for critical user flows. Flag when:
  - Logic that could be unit-tested is only exercised through integration or end-to-end tests (slow feedback, hides regressions).
  - Logic that needs real component interaction is only unit-tested with mocks (false confidence).
  - Pyramid is inverted: many e2e tests, few unit tests.
- **Test placement** — a test belongs at the lowest tier that can validate the behavior. If a unit test covers the requirement, an integration or e2e test for the same logic is duplication.

## Auditing pre-existing issues

Check version-control history to confirm an issue is from the current diff, not pre-existing. Apply the pre-existing pattern rule above.
