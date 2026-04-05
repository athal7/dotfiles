# Systems Thinking

Frameworks for understanding why a system behaves the way it does — feedback loops, relationships, and hidden structures.

---

## Connection Circles

**Use when:** Multiple elements seem to be influencing each other and you want to map the feedback structure.

**Steps:**
1. Identify 5–10 key elements (things that increase/decrease and can be described as nouns).
2. Draw arrows between elements with a direct causal relationship.
3. Label each arrow: `+` (causes increase) or `–` (causes decrease).
4. Look for closed loops — chains that cycle back to a starting element.

**Reading loops:**
- **Reinforcing loop:** all `+` signs, or even number of `–` signs → exponential growth or collapse
- **Balancing loop:** odd number of `–` signs → stability or oscillation

**Render as:**
```
Unhappy customers → (+) Support tickets
Support tickets   → (–) Response time
Response time ↓   → (+) Unhappy customers  [REINFORCING LOOP ⚠️]
```

State the implication: what does this loop structure predict about system behavior?

**Related:** Iceberg Model (deeper structures and mental models behind what connection circles reveal), Balancing Feedback Loop, Reinforcing Feedback Loop

---

## Balancing Feedback Loop

**Use when:** A system is resisting change, stabilizing unexpectedly, or oscillating around a target.

```
[Goal / Desired State]
         ↕  (gap)
[Actual State]
         ↓
[Corrective Action]  → reduces the gap
```

When a gap between goal and actual state is detected, corrective action fires to close it. Key: **the goal may not be explicit or visible.** To understand the loop, find its goal.

**Delays are dangerous:** Significant delay between corrective action and state change causes oscillation. Example: hiring to fix understaffing — by the time new hires are productive, the crisis may have passed.

**Signals:** System snaps back to baseline. Improvements keep getting cancelled out. "We keep fixing this but it keeps coming back."

**Related:** Reinforcing Feedback Loop (the complementary type), Connection Circles (mapping loops in larger system), Iceberg Model (loops are often the "structures" layer)

---

## Reinforcing Feedback Loop

**Use when:** A system is growing or declining faster than linear; a small advantage compounds into a large one; a small problem spirals.

```
[Variable A] → increases → [Variable B]
[Variable B] → increases → [Variable A]  (loop closes)
```

Can drive exponential increase **or** exponential collapse depending on direction. A vicious cycle is a reinforcing loop going the wrong way.

**Signals:** Growth or decline is accelerating. Small advantages compound. "Network effect" or "compound interest" dynamics. A small problem keeps getting worse faster than expected.

**Breaking a vicious cycle:** You don't fix it by working harder within the loop. Inject resources from outside (e.g. a dedicated debt sprint), or change a variable the loop feeds on.

**Limits to growth:** Every reinforcing loop eventually hits a balancing loop (resource constraints, market saturation). Identify these limits early — they determine the ceiling.

**Related:** Balancing Feedback Loop (often coexists in same system), Connection Circles (map the full system), Second-Order Thinking (trace how reinforcing dynamics play out over time)

---

## Concept Map

**Use when:** Need to understand or communicate how parts of a system relate — for onboarding, architecture, knowledge gaps, or team alignment.

**Steps:**
1. Define a focus question (e.g. "How does authentication work in this system?").
2. Identify 10–20 key entities (important nouns that change or interact).
3. Connect entities with labeled relationships (verbs): "depends on", "sends events to", "triggers", "validates".
4. Any two connected entities should form a readable sentence: `[A] [relationship] [B]`.
5. Look for gaps — isolated entities or missing connections are knowledge gaps or design problems.

**Render as:**
```
User → [creates] → Order
Order → [triggers] → PaymentService
PaymentService → [writes to] → PaymentsDB
```

Highlight entities with no connections (orphaned) or many connections (high-coupling risk).

**Related:** Connection Circles (for causal/feedback relationships specifically), Issue Trees (decomposing problems rather than mapping systems), Iceberg Model (when the map reveals systemic behavior to explain)
