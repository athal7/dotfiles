---
name: impact-effort-matrix
description: Prioritize tasks and initiatives using the Impact-Effort Matrix — identify quick wins, major projects, fill-ins, and thankless tasks
---

# Impact-Effort Matrix

**Category:** Decision Making

Use this when you have a list of tasks or initiatives and need to decide what to work on. Cuts through the feeling of being busy-but-ineffective by surfacing where the real leverage is.

## The Four Quadrants

|  | **Low Effort** | **High Effort** |
|--|---------------|----------------|
| **High Impact** | **Quick Wins** — do these first | **Major Projects** — plan and execute |
| **Low Impact** | **Fill-ins** — do when there's slack | **Thankless Tasks** — avoid or minimize |

### Guidance per quadrant

- **Quick Wins:** Maximum ROI. Prioritize immediately. These are often undervalued because they seem "too easy."
- **Major Projects:** Important, but require planning, resources, and sequencing. Don't let them crowd out Quick Wins.
- **Fill-ins:** Fine to do, but don't let them expand to fill available time. Time-box them.
- **Thankless Tasks:** The danger zone. Often disguised as "important work." Scrutinize these — can they be eliminated, automated, or simplified?

## Agent Workflow

When asked to prioritize a list of tasks:

1. List all tasks provided.
2. For each task, assess: How impactful? How much effort?
3. Place each in the correct quadrant — be explicit about your reasoning.
4. Output a prioritized action list:
   - Do now: all Quick Wins
   - Plan: Major Projects (in order of impact)
   - Later: Fill-ins
   - Reconsider: Thankless Tasks
5. Flag any task where impact or effort is uncertain — these need more information before placement.

## Example

| Task | Impact | Effort | Quadrant | Action |
|------|--------|--------|----------|--------|
| Add error logging to payment flow | High | Low | Quick Win | Do now |
| Redesign checkout UX | High | High | Major Project | Plan |
| Update internal wiki | Low | Low | Fill-in | When there's slack |
| Manually migrate old data | Low | High | Thankless Task | Automate or eliminate |
| Fix top user-reported bug | High | Low | Quick Win | Do now |

## Tips

- **Impact is relative to your current goals.** An improvement that doesn't move a key metric may look high-impact but isn't.
- **Effort estimates are often wrong.** Add a buffer for unknowns, especially for Major Projects.
- **Review regularly.** The matrix changes as priorities shift.
- Combine with the **Eisenhower Matrix** when urgency (deadlines) also matters.

## Related Tools

- **Eisenhower Matrix** — adds urgency dimension when deadlines matter
- **Decision Matrix** — for choosing *between* options rather than prioritizing a list
