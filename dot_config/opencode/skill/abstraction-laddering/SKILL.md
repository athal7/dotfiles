---
name: abstraction-laddering
description: Reframe a problem using abstraction laddering — ask "why" to go broader, ask "how" to go more concrete, to find better problem definitions
---

# Abstraction Laddering

**Category:** Problem Solving
**Source:** Wes O'Haire (Dropbox), Autodesk

Use this when a problem statement feels too narrow (you're solving the wrong thing) or too broad (you can't make progress). It helps you find the right level of abstraction to work at.

## The Ladder

```
         ↑ "Why?" (more abstract — broader scope, different framing)
         │
    [Abstract]
         │
    [Problem Statement]  ← start here
         │
    [Concrete]
         │
         ↓ "How?" (more concrete — specific solutions, actions)
```

- **Move up (Why?):** Understand the purpose behind the problem. This can reveal a better or broader problem to solve.
- **Move down (How?):** Generate specific solutions or more constrained problem statements.

## How to Apply

1. **Write the initial problem statement** in the middle.
2. **Ask "Why?" repeatedly** to climb to more abstract framings — stop when the scope becomes unhelpfully large.
3. **Ask "How?" from each level** to descend toward concrete solutions — this reveals multiple solution paths that the original framing might have missed.
4. **Choose the right level** to work at: abstract enough to allow creative solutions, concrete enough to act on.

## Agent Workflow

When a problem statement feels stuck or mis-framed:

1. State the original problem.
2. Climb the ladder: show 2–3 "why" levels above.
3. Descend from each level: show what "how" questions emerge at each.
4. Identify which level produces the most useful problem statement.
5. Recommend where to focus.

## Example

**Original:** "Design a better can opener"

```
Why? → "Get soup out of the can"
  Why? → "Feed people efficiently"

From "Get soup out of the can":
  How? → "Make the lid detachable without tools"
  How? → "Redesign the can to open from the bottom"
  How? → "Pre-score the lid for easy opening"

From "Design a better can opener":
  How? → "Make the grip more ergonomic"
  How? → "Make it dishwasher safe"
```

**Insight:** Staying at the original level only produces incremental improvements. Moving one level up ("get soup out of can") opens up packaging redesign as a solution space entirely.

## Software Example

**Original:** "Fix the slow database query"

```
Why? → "Reduce page load time"
  Why? → "Improve user retention"

From "Reduce page load time":
  How? → "Add a cache layer"
  How? → "Paginate the results"
  How? → "Move computation to background job"

From "Fix the slow query":
  How? → "Add an index"
  How? → "Rewrite the JOIN"
```

**Insight:** At the "fix the query" level, only query-level solutions appear. At "reduce page load time," caching and pagination become valid alternatives that may be faster to implement.

## Related Tools

- **Issue Trees** — for systematically decomposing a problem once the right level is found
- **First Principles** — for questioning the underlying assumptions of a problem
- **Productive Thinking Model** — for structured creative problem-solving once the problem is well-framed
