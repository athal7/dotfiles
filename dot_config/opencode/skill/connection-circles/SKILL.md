---
name: connection-circles
description: Map relationships and feedback loops in a system using connection circles — identify what drives what, and where loops form
---

# Connection Circles

**Category:** Systems Thinking
**Source:** Systems Thinker

Use this when you're trying to understand why a system behaves the way it does, especially when multiple elements seem to be influencing each other. Reveals feedback loops that explain runaway growth or surprising stability.

## How to Create a Connection Circle

1. **Draw a circle** (conceptually, or on a whiteboard).
2. **Identify key elements** of the system — things that: (a) are important to changes in the system, (b) increase or decrease, (c) can be described as a noun. Limit to 10 or fewer.
3. **Place elements around the circle.**
4. **Draw arrows between elements** that have a direct causal relationship: A causes B to increase or decrease.
5. **Label each arrow:** `+` (causes increase) or `–` (causes decrease).
6. **Look for closed loops** — chains of arrows that cycle back to a starting element. These are feedback loops.

## Reading the Loops

- **Reinforcing loop:** all `+` signs, or an even number of `–` signs. Produces exponential growth or collapse.
- **Balancing loop:** odd number of `–` signs. Produces stability or oscillation.

## Agent Workflow

When asked to map a system:

1. Ask the user to describe the system or situation in plain language.
2. Extract 5–10 key elements from the description.
3. Identify causal relationships: for each pair, does A directly cause B to increase or decrease?
4. Render as a structured list of relationships:
   ```
   Unhappy customers → (+) Support tickets
   Support tickets → (–) Response time quality
   Response time quality → (+) Unhappy customers  [LOOP]
   ```
5. Identify any feedback loops and label them (reinforcing or balancing).
6. State the implication: what does this loop structure predict about system behavior?

## Example

**System:** SaaS product with declining customer satisfaction

**Elements:** Unhappy customers, bugs, new features, support tickets, response time, engineer capacity

**Relationships:**
```
Unhappy customers → (+) Support tickets
Support tickets   → (–) Response time  [response slows down]
Response time ↓   → (+) Unhappy customers  [REINFORCING LOOP ⚠️]

New features      → (+) Bugs
Bugs              → (+) Unhappy customers

Engineer capacity → (–) Bugs  [more capacity = fewer bugs]
Support tickets   → (–) Engineer capacity  [support drains engineering]
```

**Loops identified:**
- Reinforcing loop: Unhappy customers → more tickets → slower response → more unhappy customers (doom spiral)
- Balancing loop: Adding engineers reduces bugs but support load grows with scale

**Implication:** Fixing bugs alone won't break the reinforcing loop — response time is the key leverage point. Reducing ticket volume (better self-serve docs, fewer bugs) breaks the loop upstream.

## Related Tools

- **Iceberg Model** — for understanding the deeper structures and mental models behind what connection circles reveal
- **Balancing Feedback Loop** — for understanding one type of loop in depth
- **Reinforcing Feedback Loop** — for understanding the other type
