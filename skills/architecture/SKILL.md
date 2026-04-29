---
name: architecture
description: Architecture decisions — option tables, decision criteria, escalation
license: MIT
metadata:
  provides:
    - architecture
  requires:
    - issues
    - code-quality
---

Use this when facing a software design decision with multiple valid approaches, hard-to-reverse consequences, or system boundary implications.

## Steps

1. **Gather context.** State the problem, constraints, and options. Use your `issues` capability for history and prior decisions if relevant. Research patterns, prior art, library docs.

2. **Present options as a table.** Always include 2+ options — never one-option-as-fait-accompli.

   | | Option A | Option B | … |
   |---|---|---|---|
   | **What it is** | … | … | … |
   | **Pros** | … | … | … |
   | **Cons** | … | … | … |
   | **Best when** | … | … | … |

3. **Score against software-architecture criteria:**

   - **Reversibility:** how painful to undo in 6 months?
   - **YAGNI:** real present problem or hypothetical?
   - **Simplicity:** which would a new team member understand fastest?
   - **Testability:** which is easiest to test in isolation?
   - **Coupling:** does it create hard dependencies that constrain future changes?
   - **Operational cost:** what does it add to deploy, monitor, debug?
   - **DX:** which is less annoying day-to-day?

   **Prefer reversibility and simplicity when criteria conflict. Complexity must earn its place.**

4. **Call out system-level anti-patterns by name** when present in any option — use the catalog under your `code-quality` capability (Premature Abstraction, Wrong Layer, Leaky Abstraction, Distributed Monolith, Config as Code, Speculative Generality).

5. **Escalate** when any of these are true; do not recommend unilaterally:

   - Irreversible at the data layer (schema changes, migration strategy)
   - Crosses service/team boundaries
   - Significant operational cost (new infrastructure, new external dependency)
   - You are genuinely uncertain after applying the framework

6. **Recommend** with one concrete sentence naming the single most important reason. Never be vague. Never present one option as if no alternatives exist.
