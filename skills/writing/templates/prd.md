# Product Requirements Document (PRD)

A PRD aligns stakeholders on *what* to build and *why* before implementation begins. It is not a spec — implementation details belong in tickets. A PRD answers: "Should we build this, and what would success look like?"

## When to write a PRD

- New feature or user-facing change that spans multiple tickets
- Significant UX or product direction change
- Work that needs sign-off from multiple stakeholders before starting
- When "we know what to build" isn't yet established

Skip the PRD if the solution is already known and agreed upon — go straight to tickets.

---

## Structure

### Problem statement
One paragraph. What user or business problem are we solving? Who has this problem, how often, and what is the cost of not solving it?

State the problem in user terms, not product terms.
- Bad: "We need to add SSO support"
- Good: "Enterprise customers with >50 seats require SSO for compliance. Without it, we lose deals at contract stage — 3 lost in Q4 alone worth $240k ARR."

### Goals
3-5 bullet points. What must be true when this ships? Write as measurable outcomes where possible.

```
- Enterprise customers can authenticate via their existing IdP (Okta, Azure AD) without IT configuring per-user accounts
- SSO setup takes <30 minutes for an IT admin with no prior context
- Existing non-SSO login remains available for customers not on Enterprise plan
```

### Non-goals
Explicitly state what this does *not* address. This prevents scope creep and clarifies boundaries.

```
- Social login (Google/GitHub) — separate initiative
- Mobile SSO — Phase 2
- Migrating existing users to SSO automatically
```

### Proposed solution
High-level approach. Not implementation detail — think "what changes from the user's perspective." Include:
- Key user flows (can reference Figma or a rough description)
- Key decisions already made and why

If multiple solution approaches were seriously considered, use a decision matrix to make the tradeoffs legible:

```markdown
| Criterion         | Approach A (chosen) | Approach B   | Approach C   |
|-------------------|:-------------------:|:------------:|:------------:|
| Time to ship      | ✅ 4 weeks          | ⚠️ 8 weeks   | ❌ 16 weeks  |
| User disruption   | ✅ None             | ⚠️ Migration | ❌ Full re-onboard |
| Ops complexity    | ⚠️ Medium           | ✅ Low       | ❌ High      |
| Long-term fit     | ⚠️ Partial          | ✅ Good      | ✅ Best      |
```

Use this when the "why this approach" question is likely to come up in review. Skip it if the solution is obvious or already agreed.

### Open questions
What do we not know yet that needs resolution before or during implementation?

```
- Open: Does "Enterprise plan" need a UI gate or is it config-only?
- Open: Which IdPs to support in v1? (SAML-only vs OIDC too)
```

### Success metrics
How will we know this worked after shipping? Name specific metrics and targets.

```
- SSO adoption: >60% of enterprise seats using SSO within 60 days of GA
- Time-to-setup: median <20 min (measured via event tracking)
- Support tickets: no increase in auth-related tickets post-launch
```

### Risks
What could go wrong?

```
- Risk: SAML library has known CVE — need security review before launch
```

---

## Fill-in template

```markdown
## Problem
[Who has what problem, how often, what is the cost?]

## Goals
- [Measurable outcome 1]
- [Measurable outcome 2]
- [Measurable outcome 3]

## Non-goals
- [Explicitly out of scope item 1]
- [Explicitly out of scope item 2]

## Proposed solution
[High-level approach. Key user flows. Key decisions made and why.]

| Criterion     | [Approach A — chosen] | [Approach B] |
|---------------|:---------------------:|:------------:|
| [Criterion 1] | ✅                    | ❌           |
| [Criterion 2] | ⚠️                    | ✅           |

## Open questions
- [Question 1]
- [Question 2]

## Success metrics
- [Metric and target 1]
- [Metric and target 2]

## Risks
- [Risk and mitigation 1]
```

---

## Common mistakes

**Writing a spec, not a PRD**: Listing API fields, database schemas, or component names is premature. Those belong in tickets or technical design docs.

**No non-goals**: Every PRD will attract scope additions. Non-goals are your defense.

**Vague goals**: "Improve the experience" is not a goal. "Users complete checkout without abandoning due to payment errors" is.

**No success metrics**: If you can't measure it, you can't declare victory.

**Too long**: A PRD that takes 30 minutes to read won't get read. Aim for a 5-minute read. Link to supporting docs rather than embedding them.

**Milestones in the doc body**: Most issue trackers have native milestone or roadmap features — use those instead of embedding a phase list in the PRD. Keep the doc focused on problem and solution; let the tracker own the schedule.
