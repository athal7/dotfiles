# Problem Framing & Root Cause

Frameworks for when a problem is unclear, recurring, or needs reframing before solving.

---

## Abstraction Laddering

**Use when:** A problem statement feels too narrow or too broad.

Ask "Why?" to climb to more abstract framings. Ask "How?" to descend toward concrete solutions. Find the level that's abstract enough to allow creative solutions but concrete enough to act on.

**Steps:**
1. Write the initial problem statement in the middle.
2. Ask "Why?" 2–3 times to climb — stop when scope becomes unhelpfully large.
3. Ask "How?" from each level to descend — reveals multiple solution paths.
4. Identify which level produces the most useful problem statement.

**Example:** "Fix the slow database query" → "Reduce page load time" → at that level, caching and pagination become valid alternatives to query tuning.

**Related:** Issue Trees (decompose once the right level is found), First Principles (question assumptions), Productive Thinking Model (once problem is well-framed)

---

## First Principles

**Use when:** You're reasoning by analogy ("this is how it's always been done") and want truly innovative solutions.

Break the problem to fundamental truths, then rebuild from scratch without inheriting assumptions.

**Techniques:**
- **Five Whys:** Repeatedly ask "Why?" to drill past symptoms. Stop when you hit something that's simply true.
- **Socratic questioning:** Clarify, probe assumptions, probe evidence, trace implications, seek alternative viewpoints, question whether you're solving the right problem.

**Steps:**
1. State the assumed solution and its assumptions.
2. Apply Five Whys or Socratic questioning to break each assumption down.
3. Identify the first principles — things that are just true.
4. Rebuild: given only those truths, what would you design from scratch?

**Example:** "We need microservices to scale" → first principles reveal: small team + uniform traffic + need for deployment speed → modular monolith is actually correct.

**Related:** Abstraction Laddering (find right problem level first), Ishikawa (structured root cause within a domain), Productive Thinking Model (full structured process)

---

## Ishikawa Diagram (Fishbone)

**Use when:** You need to identify root causes of a complex or recurring problem.

**Steps:**
1. Define the problem clearly (the "head" of the fish).
2. Identify 4–6 factor categories (for software: Code, Process, Infrastructure, People, Data, External).
3. Under each factor, ask "Why is this happening?" and list 2–4 specific causes.
4. Identify the top 2–3 most likely root causes and recommend next steps.

**Render as:**
```
Problem: [X]
├── Factor A
│   ├── Cause A1
│   └── Cause A2
├── Factor B
│   ├── Cause B1
│   └── Cause B2
```

**Related:** First Principles (deeper "why" within branches), Issue Trees (alternative decomposition), Iceberg Model (when systemic understanding is needed)

---

## Issue Trees

**Use when:** A problem is large and you don't know where to start. Makes it navigable by breaking into non-overlapping parts.

**Two types:**
- **Problem tree (Why?):** Breaks down why a problem exists.
- **Solution tree (How?):** Breaks down how to solve it.

**MECE principle:** Every branch split must be Mutually Exclusive (no overlap) and Collectively Exhaustive (nothing left out).

**Steps:**
1. State the top-level problem.
2. Split into 2–4 MECE branches (Level 1).
3. Branch each node to Level 2–3.
4. Apply 80/20: which branches most likely explain the majority? Focus there first.

**Related:** Ishikawa (better for multi-factor causal mapping), Abstraction Laddering (reframe the problem first if needed), Productive Thinking Model (structured creative solving once right branch found)

---

## Iceberg Model

**Use when:** Surface-level fixes aren't working; the same issue keeps recurring.

**Four levels:**
```
[Visible]  Events       → What is happening right now?
           Patterns     → What trends appear over time?
           Structures   → What relationships/loops drive patterns?
[Hidden]   Mental Models → What beliefs shape the system?
```

The deeper you go, the more leverage you have. Mental models and structures are where lasting change lives.

**Steps:**
1. Identify the event — the specific observable problem.
2. Surface patterns — recurrence, trends, prior instances.
3. Map structures — system elements and relationships causing patterns.
4. Surface mental models — what beliefs created or sustain those structures?
5. Recommend the highest-leverage intervention point.

**Related:** Ishikawa (cause-and-effect at event/pattern level), Connection Circles (mapping structural relationships), Feedback Loops (understanding structural dynamics)

---

## Inversion

**Use when:** You're only thinking about ideal outcomes and need to stress-test thinking.

Instead of "How do I succeed?" ask "What would guarantee failure?" Then work backward to avoid those conditions.

**Application 1 — Evaluate a plan:**
1. Ask: "What would be the worst possible approach here?"
2. Ask: "Why would it be bad? What specifically would go wrong?"
3. Check your current plan against those failure modes.

**Application 2 — Pre-mortem:**
Imagine it's 6 months from now and the project has failed. Ask: "What went wrong?" Document answers. Mitigate before starting.

**Steps:**
1. State what's being evaluated.
2. Generate 5–10 specific failure modes: "This fails if..."
3. For each, assess: already mitigated? If not, what would mitigate it?
4. Identify top 2–3 highest-risk unmitigated failures and recommend fixes.

**Related:** Second-Order Thinking (forward consequence tracing; complements inversion), Six Thinking Hats (Black Hat is the inversion perspective in groups), Productive Thinking Model (inversion used in Step 2 Restrictions/DRIVE)
