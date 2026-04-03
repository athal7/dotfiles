---
name: cynefin-framework
description: Use the Cynefin framework to classify a situation as Clear, Complicated, Complex, or Chaotic — then choose the right response approach
---

# Cynefin Framework

**Category:** Decision Making
**Pronounced:** "kuh-nev-in"
**Source:** Dave Snowden, 1999

Use this when you're unsure how to approach a situation — whether to apply a known solution, bring in experts, experiment, or simply stabilize first. Different situations genuinely require different types of responses.

## The Five Domains

### Clear (also: Obvious, Simple)
**Characteristics:** Stable, well-understood, predictable. Cause and effect are obvious. Best practices exist.

**Response:** Sense → Categorize → Respond
Apply the established best practice. Don't over-engineer.

*Examples: Deploying a standard web app, setting up DNS, onboarding a new employee with a documented process.*

---

### Complicated
**Characteristics:** There is a right answer, but finding it requires analysis or expertise. "Known unknowns."

**Response:** Sense → Analyze → Respond
Bring in experts. Assess options. Choose the best-fit solution.

*Examples: Diagnosing a performance regression, designing a database schema, evaluating a security architecture.*

---

### Complex
**Characteristics:** The situation can't be understood through analysis alone — there are "unknown unknowns." The system is dynamic; cause and effect only become clear in retrospect.

**Response:** Probe → Sense → Respond
Run experiments. Learn from what happens. Let patterns emerge before committing to a solution.

*Examples: Entering a new market, redesigning a product for a new user segment, fixing an unexplained production anomaly.*

---

### Chaotic
**Characteristics:** No clear cause-effect relationships. Things are out of control. Every second counts.

**Response:** Act → Sense → Respond
Stabilize first. Contain the situation. Then move it toward Complex to understand it.

*Examples: Active security breach, production outage with unknown cause, organizational crisis.*

---

### Disorder
**Characteristics:** You don't know which domain you're in.

**Response:** Break the problem into parts. Assign each to a domain. Proceed from there.

---

## Domain Classification Questions

| Question | Implication |
|----------|-------------|
| Do you know what's causing this? | Clear or Complicated |
| Is the situation under control? | No → Chaotic |
| Does solving it require expertise? | Complicated |
| Can you experiment safely? | Complex |
| Are cause and effect only visible in retrospect? | Complex |

## Agent Workflow

When someone is unsure how to approach a situation:

1. Ask the classification questions above.
2. Identify the domain and name it.
3. Recommend the appropriate response posture (sense-categorize-respond, etc.).
4. Flag if the situation spans multiple domains — decompose it.

## Example

**Situation:** The app is responding slowly. Users are complaining. No one knows why yet.

- Is it under control? Yes, it's degraded but not fully down.
- Do we know the cause? No.
- Can we run experiments safely? Yes — we can roll back recent changes, increase logging, run queries.

**Domain:** Complex (unknown unknowns, need to probe)

**Response:** Run probes — check recent deploys, query database slow log, profile a sample request. Don't assume a known fix. Let the data surface the pattern before acting.

---

**Situation:** Set up a new Postgres database for a standard web application.

**Domain:** Clear
**Response:** Follow the standard setup playbook. No analysis needed.

## Related Tools

- **OODA Loop** — the right decision-making loop for Complex and Chaotic domains
- **Issue Trees** — useful once you've moved from Complex into Complicated
- **First Principles** — for challenging the assumptions that categorized a situation as Clear when it might be Complicated
