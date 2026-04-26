---
name: architecture
description: Software design reasoning — architecture decisions with tradeoff tables, code-level design smells (Feature Envy, Scattered Enforcement, Shotgun Surgery, Primitive Obsession, Layering Violations), refactoring direction, and pre-implementation design prerequisite checks
license: MIT
metadata:
  provides:
    - architecture
  requires:
    - issues
---

Load this skill whenever a software design question arises at any level — system architecture, module structure, or code-level patterns. The description is the selection signal; the sections below are the three modes of use.

## Section 1: Architecture Decisions

Use this section when facing a decision with multiple valid approaches, hard-to-reverse consequences, or system boundary implications.

### How to Use

1. Gather context: the problem, constraints, and options already being considered
2. Apply the analysis prompt below to the decision — either in this session, or by spawning a subagent if a fresh context window helps
3. Present the output to the user
4. If escalation is flagged, stop and ask the user before proceeding

### Analysis Prompt Template

```
You are an architecture advisor. Analyze the following design decision and provide a clear recommendation.

## Decision

<describe the decision, constraints, and options being considered>

## Always Present Options as a Table

| | Option A | Option B | Option C |
|---|---|---|---|
| **What it is** | ... | ... | ... |
| **Pros** | ... | ... | ... |
| **Cons** | ... | ... | ... |
| **Best when** | ... | ... | ... |

Follow the table with a clear recommendation and the single most important reason for it. Never present one option as if no alternatives exist. Never be vague — always recommend.

## Decision Criteria

Evaluate options against these factors (not all will apply):

| Factor | Question to ask |
|--------|----------------|
| **Reversibility** | How painful is it to undo this in 6 months? |
| **YAGNI** | Are we solving a real, present problem or a hypothetical one? |
| **Simplicity** | Which option would a new team member understand fastest? |
| **Testability** | Which is easiest to test in isolation? |
| **Coupling** | Does this create hard dependencies that constrain future changes? |
| **Operational cost** | What does this add to deploy, monitor, and debug? |
| **DX** | Which option is less annoying to work with day-to-day? |

Prefer reversibility and simplicity when criteria conflict. Complexity must earn its place.

## Research

Look up patterns, prior art, or library docs relevant to the decision using available research tools. Use your `issues` capability to query the project and understand history and prior decisions if relevant.

## Anti-Patterns to Call Out

When you see these, name them explicitly:

| Anti-pattern | Description |
|---|---|
| **Premature abstraction** | Creating an interface/layer before there are 2+ concrete implementations |
| **Wrong layer** | Business logic in the DB, presentation logic in the service layer, etc. |
| **Leaky abstraction** | An abstraction that forces callers to know about its internals |
| **Distributed monolith** | Microservices that must all deploy together or share a database |
| **Config as code** | Logic that belongs in code ends up in feature flags or env vars |
| **Speculative generality** | Building for scale/flexibility that isn't needed yet |

## When to Flag for Escalation

If any of these are true, say so explicitly and do not recommend unilaterally:

- The decision is irreversible at the data layer (schema changes, migration strategy)
- The decision crosses service/team boundaries
- The decision has significant operational cost (new infrastructure, new external dependency)
- You are genuinely uncertain which option is better after applying the criteria

## Output Format

1. Option table
2. Recommendation paragraph (concrete, single best reason)
3. Any anti-patterns spotted
4. Escalation flag if applicable
```

## Section 2: Code-Level Design Smells

Use this section when reviewing existing code or a diff for structural problems that make the system harder to change. Scan each category below.

### Tell, Don't Ask / Feature Envy

Look for callsites that pull state out of an object to make a decision the object should make itself.

Signals to grep for:
- Multiple files checking the same attribute chain (e.g. `record.status == :locked`, `record.full_lock?`, `record.state == "offered"`) to gate different behaviors
- The same conditional logic duplicated across services, controllers, views, and helpers
- A new method that replicates a check already in another layer

When found: name the violated object, list every callsite, and suggest where the logic belongs (policy, model method, service). If the code being reviewed *adds* another callsite to an already-scattered pattern, this is a **blocker** — the change entrenches the smell.

### Scattered Enforcement

A specific form of Tell Don't Ask: authorization or validation rules enforced in multiple places independently.

Look for:
- Access decisions made in a controller, a service, AND a view for the same concept
- Pundit policy methods partially redundant with service-layer guards
- Lock/state checks in helpers and views that duplicate service-level rules

Flag: "This rule is enforced in N places — [list them]. Any new callsite should go through [central point] instead."

### Shotgun Surgery

A change that touches many files to implement one logical rule. If a single business rule change requires edits to 5+ unrelated files, the rule is not encapsulated.

The signal: one issue ticket, one logical change, many files all doing slightly different versions of the same thing.

### Primitive Obsession / Data Clumps

- A group of primitives (strings, integers, booleans) passed together repeatedly where a value object would clarify intent
- Domain concepts expressed as raw strings or magic numbers rather than named types
- A parameter hash that grows beyond 3–4 keys and always travels together

### Layering Violations

- Business logic in a view or controller (decision-making that belongs in a service or model)
- Persistence logic leaking into domain objects (ActiveRecord queries in presenters/helpers)
- A view rendering conditional that encodes a business rule (should be a policy or presenter method)

### Anemic Domain Model (Evans)

- Rich service classes that do all the work while the model is just a data bag
- Methods on the model that only do `self.field = value; save` — logic that should be behavior
- New service files that reconstruct domain knowledge already implicit in the model

Only flag when the code being reviewed adds to this pattern, not when it pre-exists.

### Anti-Extensibility Conditionals

- A new `if/elsif/case` on a type, state, or role where polymorphism or a strategy object would eliminate future N+1 branching
- An existing `case` that is extended by adding another branch — flag "this case has N arms now; consider a table or strategy pattern"

### Coupling Introduced

- A new cross-module dependency (module A now imports module B which previously had no relationship)
- A new parameter that must be threaded through multiple layers
- A new shared mutable structure (global config, class-level state) that creates hidden coupling

### Pre-Existing Pattern Rule

**"Make the change easy, then make the easy change."** — Kent Beck

When the code being reviewed touches a pre-existing design smell:

- If the change **does not worsen** the smell (reads it, passes through, does not add a new callsite): skip it. The reviewer's job is the diff, not the whole codebase.
- If the change **adds another callsite** to a scattered pattern: flag as `blocker` — this is the moment to stop and extract.
- If the change **depends on** a pre-existing bad design to work correctly (i.e. it would be simpler if the smell were fixed first): flag as `suggestion` with: "Consider extracting [X] first as a prerequisite — it would simplify this and prevent future rework." Suggest filing a separate issue.

Never flag ambient smell the code doesn't interact with.

### Naming and Severity

For each smell found: name the pattern (e.g. "Feature Envy", "Scattered Enforcement"), cite Fowler or Evans, and propose a concrete refactoring direction (e.g. "Move Method to X", "Replace Conditional with Polymorphism", "Extract Policy object").

Severity: `blocker` if the change entrenches a pre-existing scattered pattern by adding another callsite; `suggestion` if it introduces a new smell; `suggestion` if a prerequisite refactor would simplify the work.

## Section 3: Design Prerequisite Check

Use this section before planning any implementation that touches domain logic, authorization, state machines, or anything enforced in more than one layer. Answer each question by reading the relevant code before writing a single line of implementation.

**Scattered enforcement:** Does the feature touch any concept (lock state, authorization, validation, pricing rule, etc.) that is currently checked or enforced in multiple places independently? List every callsite you find. If yes: is centralizing that concept first a prerequisite that would make the implementation simpler and avoid rework?

**Coupling:** Will this change add a new dependency between modules that had no prior relationship? Is there a cleaner seam?

**Extensibility:** Is the design choice being made the 2nd or 3rd instance of a pattern that will need to exist in N places? If so, is there a single abstraction that serves all of them?

**"Make the change easy, then make the easy change."** If a prerequisite refactor would simplify the work, surface it explicitly: propose a separate issue/PR for the refactor, get user confirmation on whether to do it first, and only then plan the feature. This is how to avoid the rework loop of building on a cracked foundation.
