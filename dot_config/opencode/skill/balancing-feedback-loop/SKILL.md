---
name: balancing-feedback-loop
description: Identify and reason about balancing feedback loops — self-correcting mechanisms that push systems toward a goal or stable state
---

# Balancing Feedback Loop

**Category:** Systems Thinking
**Source:** Donnella Meadows, *Thinking in Systems*

Use this when a system seems to be resisting change, stabilizing unexpectedly, or oscillating around a target. Balancing loops explain self-correcting behavior.

## How It Works

A balancing feedback loop has three components:

```
[Goal / Desired State]
         ↕  (gap)
[Actual State]
         ↓
[Corrective Action]  → reduces the gap
         ↓
[Actual State changes] → loop repeats
```

When the loop detects a gap between the goal and the actual state, it triggers a corrective action to close that gap. The loop keeps running until the gap is eliminated — or until external forces shift the goal or disrupt the correction.

**Key:** To understand a balancing loop, find its goal. The goal may not be explicit or visible.

## Identifying a Balancing Loop

Signals that a balancing loop is at work:
- A system resists change and snaps back toward a baseline
- Attempts to improve something keep getting cancelled out
- Oscillation around a stable point
- "We keep fixing this, but it keeps coming back"

## Agent Workflow

When a system seems to be resisting change or stabilizing:

1. Identify what is being held stable (the actual state).
2. Identify the goal or desired state the loop is targeting.
3. Identify the corrective mechanism — what triggers when there's a gap?
4. Describe the full loop: gap → corrective action → actual state change → new gap assessment.
5. Identify any delays in the loop (delays cause oscillation).
6. Ask: is this loop desirable? If it's preventing a needed change, how do you shift the goal, not just fight the correction?

## Example

**Thermostat (simple):**
- Goal: 68°F
- Actual: 64°F
- Gap: –4°F
- Corrective action: heater turns on
- Result: room warms to 68°F, heater turns off

---

**Software example — bug fixing loop:**

- Goal: low bug count
- Actual: high bug count (after a major release)
- Gap: too many bugs
- Corrective action: engineers are pulled from feature work to fix bugs
- Result: bug count drops
- Side effect: feature velocity drops → next release has fewer new bugs introduced → bug count stays low

**But:** If the goal is implicitly "keep bug count low enough that customers don't escalate," the loop may stabilize at a higher bug count than ideal — just below the escalation threshold.

**Insight:** The goal of a balancing loop matters enormously. A team that only fixes bugs when customers escalate has a balancing loop with the wrong goal. Change the goal (e.g., track bugs proactively), and the corrective actions change.

## Delays Are Dangerous

When there's a significant delay between corrective action and the change in actual state, the system can overcorrect — producing oscillation rather than smooth stabilization.

*Example: Hiring to fix understaffing. New hires take 3 months to onboard. If hiring decisions are made on current workload, by the time new hires are productive, the crisis may have passed — leaving the team overstaffed.*

## Related Tools

- **Reinforcing Feedback Loop** — the opposite type; produces exponential change rather than stability
- **Connection Circles** — for mapping feedback loops within a larger system
- **Iceberg Model** — balancing loops are often the "structures" layer of the iceberg
