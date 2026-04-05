# Decision Making

Frameworks for choosing between options, calibrating effort, prioritizing, and navigating uncertainty.

---

## Hard Choice Model

**Use first** — before investing effort in any decision. Calibrates how much deliberation is warranted.

| | Easy to Compare | Hard to Compare |
|--|--|--|
| **High Impact** | Big Choice — take time, gather info | Hard Choice — accept uncertainty, use frameworks |
| **Low Impact** | No-Brainer — decide immediately | Apples & Oranges — decide by current priorities |

**Steps:**
1. Assess: How significant is the outcome?
2. Assess: How easy is it to compare the options?
3. Name the decision type and recommend approach.
4. For Hard Choices: use Decision Matrix + experiments. For No-Brainers: decide immediately.

**Common mistake:** Spending hours on No-Brainers while underinvesting in Hard Choices.

**Related:** Decision Matrix (for Big/Hard Choices), Eisenhower Matrix (if deciding about tasks not options), OODA Loop (if speed matters despite incomplete information)

---

## Decision Matrix

**Use when:** Multiple options, multiple factors to weigh. Removes subjectivity, makes tradeoffs explicit.

**Steps:**
1. List options (rows) and factors (columns).
2. Score each option per factor (1–5, where 5 = best).
3. Assign weights to each factor (importance).
4. Calculate: `score × weight` per cell, sum per option.
5. Pick highest total — but flag if result is within 10% (genuinely hard decision).

**Tips:** Weights matter more than scores. Don't retroactively fit scores to match your gut. Keep factors to 3–6.

**Related:** Hard Choice Model (use first to calibrate effort), Impact-Effort Matrix (simpler for task prioritization), Six Thinking Hats (qualitative perspective-gathering before scoring)

---

## Eisenhower Matrix

**Use when:** Busy but not making progress on what matters; need to prioritize a task backlog.

| | Urgent | Not Urgent |
|--|--|--|
| **Important** | Q1: Do it — crises, deadlines | Q2: Schedule it — deep work, goals |
| **Not Important** | Q3: Delegate it — admin, others' requests | Q4: Eliminate it — busywork |

Priority order: Q2 > Q1 > Q3 > Q4. Q2 (important but not urgent) is where strategic leverage lives — and gets most neglected.

**Related:** Impact-Effort Matrix (alternative; focuses on effort vs. impact), Hard Choice Model (when importance itself is unclear)

---

## Impact-Effort Matrix

**Use when:** Prioritizing a list of tasks or initiatives. Cuts through busy-but-ineffective feeling.

| | Low Effort | High Effort |
|--|--|--|
| **High Impact** | Quick Wins — do first | Major Projects — plan and execute |
| **Low Impact** | Fill-ins — when there's slack | Thankless Tasks — avoid or minimize |

Scrutinize Thankless Tasks — often disguised as important work. Flag if impact or effort is uncertain — those need more information before placement.

**Related:** Eisenhower Matrix (adds urgency when deadlines matter), Decision Matrix (for choosing between options rather than prioritizing a list)

---

## Cynefin Framework

**Use when:** Unsure whether to apply a known solution, bring in experts, experiment, or stabilize first.

| Domain | Characteristics | Response |
|--------|----------------|----------|
| **Clear** | Obvious cause/effect, best practices exist | Sense → Categorize → Respond (apply best practice) |
| **Complicated** | Right answer exists, needs expertise | Sense → Analyze → Respond (bring in experts) |
| **Complex** | Unknown unknowns, only clear in retrospect | Probe → Sense → Respond (experiment first) |
| **Chaotic** | No cause/effect relationships, out of control | Act → Sense → Respond (stabilize first) |
| **Disorder** | Don't know which domain you're in | Break into parts, assign each to a domain |

**Classification questions:** Do you know what's causing this? Is it under control? Does solving it require expertise? Can you experiment safely?

**Related:** OODA Loop (right decision loop for Complex/Chaotic), Issue Trees (useful once moved from Complex into Complicated), First Principles (challenge assumptions that classified something as Clear)

---

## OODA Loop

**Use when:** Fast-moving, competitive, or ambiguous situations where you can't wait for complete information. Goal: cycle faster, not just make good decisions.

**Observe → Orient → Sense → Act**

- **Observe:** Gather information quickly. Stale data leads to stale decisions.
- **Orient:** Synthesize — challenge assumptions, consider multiple interpretations. Most important phase.
- **Decide:** Make a time-bounded bet. Imperfect decision made quickly often beats perfect decision made slowly.
- **Act:** Implement. Output feeds back into next Observe phase.

**When not to use:** High-stakes irreversible decisions. Use Second-Order Thinking or Decision Matrix instead. OODA is best for reversible or testable decisions.

**Related:** Second-Order Thinking (for high-stakes/irreversible decisions), Hard Choice Model (calibrate how much deliberation is warranted), Cynefin (understand whether situation calls for OODA-style experimentation or expert analysis)

---

## Second-Order Thinking

**Use when:** A decision seems straightforward but might have unintended downstream effects.

- **First-order:** What is the immediate effect?
- **Second-order:** What happens as a result of that effect? And then what?

**Method 1 — "And then what?":**
1. List 3–5 immediate first-order effects.
2. For each, ask "And then what?" 1–2 levels deeper.
3. Highlight non-obvious or counter-intuitive second-order effects.

**Method 2 — 10/10/10 Timelines:**
What are the consequences in 10 minutes? 10 months? 10 years?

**Common traps:** Assuming effects are linear (they compound). Stopping at one level. Only tracing negative chains.

**Related:** Inversion (pair to find worst-case chains), Iceberg Model (systemic hidden causes vs. downstream effects), Feedback Loops (second-order effects often involve feedback dynamics)

---

## Six Thinking Hats

**Use when:** Need to examine a decision from multiple angles to avoid overlooking important aspects.

| Hat | Focus |
|-----|-------|
| **Yellow** | Benefits, opportunities |
| **Green** | Creative options, unexplored ideas |
| **Red** | Emotions, intuition |
| **White** | Data, facts, trends |
| **Black** | Worst-case, what might not work |
| **Blue** | Process — is discussion making progress? |

Work through each hat sequentially. Yellow first (start with benefits). Black to stress-test. White to ground in data. Green to generate alternatives. Blue to facilitate.

**Related:** Inversion (pairs with Black hat), Decision Matrix (score options after Six Hats), Productive Thinking Model (deeper creative generation for Green hat)

---

## Confidence → Speed vs. Quality

**Use when:** Deciding how much polish, testing, or rigor to invest before shipping.

| Confidence in Problem | Confidence in Solution | Prioritize |
|--|--|--|
| Low | Any | Speed — validate the problem first |
| High | Low | Both — iterate and instrument |
| High | High | Quality — build it right, it's worth it |

Confidence must be based on data, not intuition. Building high-quality solutions to problems that don't matter is waste.

**Related:** Hard Choice Model (calibrate deliberation effort), OODA Loop (when speed is essential), Impact-Effort Matrix (prioritizing across features)

---

## Ladder of Inference

**Use when:** About to act on a strong conclusion but the reasoning may have skipped steps. Also for challenging others' conclusions without confrontation.

**Seven rungs (bottom to top):**
```
7. Actions
6. Beliefs
5. Conclusions
4. Assumptions
3. Interpretations
2. Selected data
1. Available data
```

We climb unconsciously and fast. The danger: jumping from "I selected this data" directly to "I'm taking this action."

**Work down the ladder:** What data did I select? What did I ignore? What interpretation did I apply? What assumption am I making? Is my conclusion the only one possible?

**Related:** Situation-Behavior-Impact (check your interpretation before giving feedback), Conflict Resolution Diagram (when a conclusion has led to a conflict)
