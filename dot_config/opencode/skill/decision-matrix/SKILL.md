---
name: decision-matrix
description: Apply a weighted decision matrix to choose between options when multiple factors matter — score, weight, and rank to find the best choice
---

# Decision Matrix

**Category:** Decision Making

Use this when you have multiple options and multiple factors to weigh, and intuition alone isn't sufficient. Removes subjectivity and makes tradeoffs explicit.

## Steps

1. **Define the decision** to make.
2. **List the options** (rows).
3. **Identify the factors** that matter (columns).
4. **Score each option** on each factor (1–5 scale, where 5 = best).
5. **Assign weights** to each factor (how important is it relative to others?).
6. **Calculate scores:** `score × weight` for each cell, then sum per option.
7. **Pick the winner** — highest total score.

## Agent Workflow

When asked to apply a decision matrix:

1. Clarify the options and factors (ask if not provided).
2. Propose factor weights based on stated priorities.
3. Score each option per factor — explain each score briefly.
4. Show the weighted totals.
5. State the winner, but also flag if the result is close (within 10%) — in that case, the decision may hinge on which factors matter most.

## Example

**Decision:** Which JS framework to use for a new project?

| Factor | Weight | React | Vue | Svelte |
|--------|--------|-------|-----|--------|
| Team familiarity | 5 | 5×5=25 | 3×5=15 | 1×5=5 |
| Ecosystem/libraries | 4 | 5×4=20 | 4×4=16 | 3×4=12 |
| Performance | 3 | 3×3=9 | 3×3=9 | 5×3=15 |
| Bundle size | 2 | 2×2=4 | 3×2=6 | 5×2=10 |
| **Total** | | **58** | **46** | **42** |

**Winner:** React — primarily because of team familiarity weight. If performance were weighted higher, Svelte would win. Make the tradeoff explicit.

## Tips

- **Weights matter more than scores.** A 5-weight factor dominates. Challenge your weights first.
- **Close results (within 10%)** signal the decision is genuinely hard — use the Hard Choice Model.
- **Don't retroactively fit scores** to match your gut — do scoring before seeing totals.
- Keep factors to 3–6; more adds noise.

## Related Tools

- **Hard Choice Model** — use first if you're unsure how much effort the decision deserves
- **Impact-Effort Matrix** — simpler prioritization for tasks (not multi-factor option selection)
- **Six Thinking Hats** — for qualitative perspective-gathering before scoring
