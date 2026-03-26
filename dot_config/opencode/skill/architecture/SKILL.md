---
name: architecture
description: Architecture decision framework — tradeoffs, criteria, anti-patterns, and escalation rules
---

## When to Load This Skill

Load this skill whenever a meaningful design decision is at stake — even if the user didn't use the word "architecture". Signs:

- Multiple valid approaches exist with real tradeoffs
- The choice will be hard to reverse later
- The decision touches system boundaries, data flow, or module structure
- You're about to introduce a new abstraction or pattern

## How to Use

1. Gather context: the problem, constraints, and any options already being considered
2. Spawn the `expert` agent with the prompt below, passing the decision description
3. Present its output to the user
4. If the agent flags escalation, stop and ask the user before proceeding

## Expert Agent Prompt Template

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

Use webfetch or context7 to look up patterns, prior art, or library docs relevant to the decision. Load the `linear` skill and query the project via `gq` to understand project history and prior decisions if relevant.

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
