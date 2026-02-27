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
2. Spawn the `architecture` agent with a clear description of the decision
3. Present its output to the user
4. If the agent flags escalation, stop and ask the user before proceeding
