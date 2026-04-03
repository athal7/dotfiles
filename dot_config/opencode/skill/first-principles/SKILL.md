---
name: first-principles
description: Apply first-principles thinking to break a problem down to fundamental truths, then build solutions from the ground up rather than from analogy
---

# First Principles

**Category:** Problem Solving
**Also called:** Reasoning from first principles
**Source:** Aristotle; popularized by Elon Musk, Shane Parrish, Wes O'Haire

Use this when you're reasoning by analogy ("this is how it's always been done") and want to find truly innovative solutions. First-principles thinking strips away assumptions and rebuilds from what is actually true.

## The Core Idea

A **first principle** is a fundamental truth that cannot be broken down further. First-principles thinking means:

1. **Break the problem down** to its most basic, unchallengeable truths.
2. **Rebuild a solution** from those truths — without inheriting the assumptions baked into existing solutions.

The opposite: reasoning by analogy — copying how others solved similar problems without questioning whether their approach is actually optimal.

## Techniques

### Five Whys
Repeatedly ask "Why?" to drill past symptoms and assumptions to root causes.

> "Why is our API slow?" → "Database queries are slow." → "Why?" → "We're doing N+1 queries." → "Why?" → "The ORM's default behavior." → "Why is that the default?" → "It's optimized for simplicity, not scale."

Each "why" strips another layer of assumption. Stop when you hit something that's simply true.

### Socratic Questioning
Six types of questions for disciplined decomposition:

| Type | Example |
|------|---------|
| Clarification | "What exactly do we mean by 'performance'?" |
| Probe assumptions | "What are we assuming about how users behave?" |
| Probe evidence | "What evidence do we have that this is the cause?" |
| Implications | "If that's true, what else must be true?" |
| Alternative viewpoints | "Is there another explanation?" |
| Question the question | "Are we solving the right problem?" |

## Agent Workflow

When a solution feels inherited from convention or analogy:

1. State the problem and the assumed solution.
2. Ask: What assumptions are baked into this solution?
3. Apply Five Whys or Socratic questioning to break down each assumption.
4. Identify the first principles — the things that are just true.
5. Rebuild: given only those truths, what solution would you design from scratch?
6. Compare to the assumed solution — what's different? What's better?

## Example

**Assumed approach:** "We need a microservices architecture to scale."

**First-principles breakdown:**
- Why microservices? → "To scale different services independently."
- Why do we need to scale independently? → "Some services get more traffic than others."
- Is that actually true for us? → "Not yet. We have uniform traffic patterns."
- What are we actually optimizing for? → "Developer velocity and deployment speed."
- What are the fundamental truths? → (1) We need fast deployments. (2) We have a small team. (3) Operational complexity has a cost.
- What solution emerges from first principles? → A well-structured modular monolith with clear boundaries — not microservices.

**Insight:** The microservices assumption was borrowed from large-scale companies. It doesn't follow from first principles for this team's actual situation.

## When to Use

- When "best practices" are being followed without examining whether they apply
- When an existing solution isn't working and you don't know why
- When you're trying to innovate rather than iterate
- When an assumption is treated as a constraint but might not be one

## Related Tools

- **Abstraction Laddering** — for finding the right problem level before applying first principles
- **Ishikawa Diagram** — for structured root-cause analysis within a specific domain
- **Productive Thinking Model** — for a full structured problem-solving process that incorporates first principles thinking
