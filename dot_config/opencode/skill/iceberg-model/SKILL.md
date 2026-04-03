---
name: iceberg-model
description: Apply the Iceberg Model to uncover root causes of events by examining patterns, system structures, and mental models beneath the surface
---

# Iceberg Model

**Category:** Systems Thinking
**Source:** Systems thinking tradition; visualized by Justin Farrugia

Use this when surface-level reactions to problems aren't working — when the same issues keep recurring despite fixes, or when you need to understand *why* a system behaves the way it does.

## The Four Levels

```
[Visible]   Events       → What is happening right now?
            ↓
            Patterns     → What trends appear over time?
            ↓
            Structures   → What relationships and feedback loops drive those patterns?
            ↓
[Hidden]    Mental Models → What beliefs and assumptions shape the system?
```

**Events and patterns** tell you *what* is happening.
**Structures and mental models** tell you *why* it's happening.

The deeper you go, the more leverage you have to create lasting change.

## Guiding Questions Per Level

### Events
- What is happening right now, specifically?
- What triggered this investigation?

### Patterns
- Has this happened before? How often?
- What trends exist over weeks, months, quarters?
- Is this getting better or worse over time?

### Structures
- What relationships between parts of the system cause these patterns?
- Where are the feedback loops?
- What incentives, processes, or constraints are shaping behavior?

### Mental Models
- What assumptions do people hold that make sense of this structure?
- What beliefs are treated as "just how things work"?
- What would have to be true for someone to design a system like this?

## Agent Workflow

When asked to apply the Iceberg Model:

1. **Identify the event** — the specific observable problem.
2. **Surface the patterns** — look for recurrence, trends, prior instances.
3. **Map the structures** — identify the system elements and relationships causing the patterns.
4. **Surface mental models** — what beliefs or assumptions created or sustain those structures?
5. **Recommend leverage points** — where is the highest-leverage intervention? (Usually structures or mental models.)

## Example

**Event:** Several bugs shipped in the last three releases.

**Patterns:** Every feature release ships with bugs. QA only happens post-release.

**Structures:**
- Teams have tight deadlines with no time budgeted for testing
- QA is siloed — developers don't own quality
- Deployment and feature work are coupled — can't ship fixes without features

**Mental Models:**
- "Shipping fast is more important than shipping right"
- "QA is someone else's job"
- "Managers set deadlines; engineers just execute"

**Leverage point:** Changing the mental model around quality ownership and budgeting test time into sprint planning — not just adding more QA headcount.

## Related Tools

- **Ishikawa Diagram** — for cause-and-effect mapping at the event/pattern level
- **Connection Circles** — for mapping structural relationships visually
- **Balancing/Reinforcing Feedback Loops** — for understanding structural dynamics
