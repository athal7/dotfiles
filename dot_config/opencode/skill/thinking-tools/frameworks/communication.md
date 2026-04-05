# Communication

Frameworks for writing clearly, giving feedback, and resolving conflict.

---

## Minto Pyramid (BLUF)

**Use when:** Writing anything that needs to be read by busy people — proposals, postmortems, design docs, status updates, Slack messages requiring a decision.

**Structure:**
```
[Conclusion / Recommendation]  ← lead with this
         ↓
[Key Argument 1]  [Key Argument 2]  [Key Argument 3]  ← why
         ↓              ↓               ↓
[Supporting detail / evidence]                         ← for those who need it
```

Counter-intuitive but effective: **the busier the audience, the more they need the conclusion first.**

**Steps:**
1. What is the one-sentence conclusion or recommendation?
2. What are the 2–4 strongest reasons to support it?
3. What data or evidence backs each reason?
4. Check: can someone reading only the first paragraph make an informed decision?

**Example:**
> ❌ "We've been looking at our database setup. SQLite was chosen for simplicity. However we've been seeing concurrency issues..."
> ✅ "**Recommend:** Migrate from SQLite to Postgres in Q3. It's blocking scale and the migration is low-risk. [Why: 47 write errors/week, 3-week migration already scoped, complete rollback plan.]"

**Related:** Situation-Behavior-Impact (for feedback specifically), Issue Trees (structuring the supporting detail section of complex documents)

---

## Situation-Behavior-Impact (SBI)

**Use when:** Giving feedback — especially corrective — to avoid judgment, generalization, and defensiveness.

**Structure:**
1. **Situation:** Specific context where the behavior occurred. ("In Monday's architecture discussion...")
2. **Behavior:** Observable actions only — no interpretation, no labels. ("...you merged the PR without flagging it in the channel...")
3. **Impact:** Effect on you, others, or the work. ("...which meant two engineers had to stop mid-task to handle conflicts. I felt blindsided.")
4. **Intent (optional):** Ask what their thinking was. Opens dialogue. ("Was there a reason you moved quickly on that one?")

**Tips:**
- Positive feedback works the same way — prevents vague praise.
- One behavior per session. Stacking feels like an attack.
- Impact > intent. Even if intent was good, the impact is real.

**Related:** Ladder of Inference (check your interpretation is well-founded before giving feedback), Conflict Resolution Diagram (when the feedback conversation escalates into conflict)

---

## Conflict Resolution Diagram (Evaporating Cloud)

**Use when:** Two parties are stuck in opposing positions and neither proposal is fully acceptable.

**Structure:**
```
[Shared Objective]
     /         \
[Need A]     [Need B]
     |             |
[Demand A]  [Demand B]  ← mutually exclusive (the conflict)
```

The conflict exists at the **demand** level, but both parties usually share a **common objective**. Finding that shared objective makes resolution possible.

**Steps (work right to left):**
1. Identify the demands — the mutually exclusive positions.
2. Identify the underlying need each demand satisfies.
3. Find the shared objective — what goal would be achieved if both needs were met?
4. Surface the assumption that makes each demand feel like the *only* way to satisfy the need.
5. Build a win-win that satisfies both needs without requiring either party to capitulate.

**Example:**
- Demand A: Full redesign. Demand B: No redesign.
- Need A: Better conversion. Need B: Minimize resource risk.
- Shared objective: Run a profitable business.
- Win-win: Targeted landing page experiments — low commitment, measurable impact.

**Related:** Six Thinking Hats (structured multi-perspective exploration before/after), Decision Matrix (evaluating win-win solution candidates)
