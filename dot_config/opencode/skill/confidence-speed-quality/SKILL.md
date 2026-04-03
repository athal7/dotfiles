---
name: confidence-speed-quality
description: Determine the right speed-quality tradeoff in product development based on your confidence in the problem and the solution
---

# Confidence Determines Speed vs. Quality

**Category:** Decision Making
**Source:** Brandon Chu, *Product Management Mental Models for Everyone*

Use this when deciding how much polish, testing, or rigor to invest in a feature or fix before shipping. Prevents both premature perfectionism and reckless shipping.

## The Framework

Your decision to prioritize **speed** or **quality** should be driven by your confidence in two things:

1. **Confidence in the problem:** Is this actually an important problem worth solving?
2. **Confidence in the solution:** Is this the right solution to that problem?

### The Three Outcomes

| Confidence in Problem | Confidence in Solution | Prioritize |
|----------------------|----------------------|-----------|
| Low | Low or High | **Speed** — validate the problem first |
| High | Low | **Both** — you know it matters, but you're still learning what works |
| High | High | **Quality** — build it right; it's worth it |

Confidence is a scale, not a switch — the outcome should be proportionally nuanced.

## Why This Matters

Building high-quality solutions to problems that don't matter is waste.
Building low-quality solutions to well-understood problems creates technical debt that compounds.
The middle case (high problem confidence, low solution confidence) is where iterative shipping and experimentation belong.

## Establishing Confidence

**Confidence must be based on data**, not intuition or organizational pressure.

| Type | How to build confidence |
|------|------------------------|
| Problem | User research, support tickets, analytics, churn reasons, market data |
| Solution | Prototypes, A/B tests, user testing, prior art, technical spikes |

## Agent Workflow

When asked how much to invest in a feature before shipping:

1. Ask: What's the evidence that this is an important problem? (Rate confidence: Low / Medium / High)
2. Ask: What's the evidence that this solution is the right one? (Rate confidence: Low / Medium / High)
3. Apply the matrix — recommend speed, quality, or balance.
4. Specify what "speed" means: what corners can be cut safely? What must still be solid?
5. Specify what "quality" means: what additional investment is justified?

## Example

**Feature:** Add a dark mode.

- Problem confidence: **High** — heavily requested for 2 years, top item in NPS comments, competitor advantage
- Solution confidence: **High** — well-understood UX pattern, clear implementation path, user expectations are well-defined

**Recommendation:** Prioritize quality. Get the contrast ratios right. Test across devices. Respect `prefers-color-scheme`. Don't ship a half-finished implementation — it will feel worse than not having it.

---

**Feature:** A new onboarding flow to improve activation.

- Problem confidence: **High** — activation rate is the top metric gap
- Solution confidence: **Low** — we're guessing which steps cause drop-off

**Recommendation:** Balance speed and quality. Ship the new flow quickly behind a flag, but instrument it thoroughly. The instrumentation *is* the quality investment — it generates the data to increase solution confidence on the next iteration.

## Related Tools

- **Hard Choice Model** — for calibrating how much deliberation a decision deserves overall
- **OODA Loop** — when speed is essential and iteration is the primary learning mechanism
- **Impact-Effort Matrix** — for prioritizing across multiple features/tasks
