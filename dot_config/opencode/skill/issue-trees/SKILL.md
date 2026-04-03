---
name: issue-trees
description: Decompose a problem into a structured tree using issue trees — ask "why" for problem trees, "how" for solution trees, following the MECE principle
---

# Issue Trees

**Category:** Problem Solving
**Source:** McKinsey consulting tradition; documented on Crafting Cases

Use this when a problem is large, complex, or hard to know where to start. Issue trees make the problem navigable by breaking it into smaller, non-overlapping parts — then focusing effort on the most impactful branches.

## Two Types

### Problem Tree (Why?)
Breaks down *why* a problem exists. Work top-down by repeatedly asking "Why is this happening?"

### Solution Tree (How?)
Breaks down *how* to solve a problem or achieve a goal. Work top-down by repeatedly asking "How might we fix/improve this?"

Use a Problem Tree first to locate the root cause, then a Solution Tree to generate solutions for that specific cause.

## The MECE Principle

Every branch split must be:
- **Mutually Exclusive:** No overlap between branches. Each cause/solution belongs to exactly one branch.
- **Collectively Exhaustive:** Together, the branches cover the whole problem. Nothing important is left out.

MECE keeps the tree rigorous and prevents double-counting effort.

## How to Build

1. **State the top-level problem** (or goal, for a solution tree).
2. **Split into 2–4 major branches** — first-level categories that together cover the full problem space. Apply MECE.
3. **Branch each node** further with the same MECE test. Continue until branches are specific enough to investigate or act on.
4. **Apply the 80/20 rule:** Which branches are most likely to explain the majority of the problem? Focus investigation there first.
5. **Test hypotheses:** Once the tree is built, identify which branches are most actionable and gather data to validate.

## Agent Workflow

When asked to apply an issue tree:

1. State the top-level problem clearly.
2. Build Level 1: 2–4 MECE branches.
3. Expand each branch to Level 2, sometimes Level 3.
4. Render as an indented list.
5. Apply 80/20: highlight which branches to investigate or prioritize first.
6. If it's a problem tree: recommend next investigative steps. If it's a solution tree: recommend which solution paths to develop.

## Example

**Problem:** Low adoption of Feature X

```
Low adoption of Feature X
├── Customers don't know about the feature
│   ├── Feature is not discoverable inside the product
│   └── Customers don't learn about it from external channels
└── Customers know about it but don't use it
    ├── Haven't tried it yet
    │   └── Don't believe it will help them
    └── Tried it but chose not to continue
        ├── Feature is not usable (UX friction)
        ├── Feature is not working correctly (bugs)
        └── Feature doesn't meet their actual needs
```

**80/20 assessment:** Start with "don't know about the feature" — it's testable (check discoverability with a quick user test) and if true, it's the upstream cause of both branches. No point fixing UX if customers never find the feature.

## Tips

- First-level splits are the most important. Spend time getting them MECE before going deeper.
- Keep leaves specific enough to be testable or actionable.
- Don't go deeper than 3–4 levels — trees get unwieldy.
- Label each node as a question or hypothesis, not a statement of fact.

## Related Tools

- **Ishikawa Diagram** — alternative for root cause analysis; better for multi-factor causal mapping
- **Abstraction Laddering** — use first if the problem statement itself needs reframing
- **Productive Thinking Model** — for structured creative problem-solving once the right branch is identified
