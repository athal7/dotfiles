---
name: plan
description: Present a plan and wait for user approval before implementing — load when a change spans multiple files or involves design decisions
license: MIT
compatibility: opencode
metadata:
  provides:
    - plan
---

Skip for typo fixes, single-line config changes, and trivial one-file edits.

1. **Research.** Explore the codebase, read relevant files, check git history. Use available capabilities (issues, meetings, logs) to gather context. Only ask the user when information isn't discoverable.

2. **Design prerequisite check.** For any change touching domain logic, authorization, state machines, or anything enforced in more than one layer — read the relevant code and answer:
   - **Scattered enforcement:** is this concept already checked in multiple places? List callsites. If yes, is centralizing first a prerequisite?
   - **Coupling:** does this add a new dependency between modules that had no prior relationship?
   - **Extensibility:** is this the 2nd or 3rd instance of a pattern? Is there a single abstraction that serves all of them?

   If a prerequisite refactor would simplify the work, surface it: propose a separate issue/PR, get user confirmation, do it first.

3. **Write the plan.** Include: files that will change and why; approach and key decisions; risks or open questions; the first failing test you will write.

4. **Present and STOP.** End your response. Wait for explicit approval — "yes", "approved", "lgtm", "go ahead", or equivalent. After approval, implementation begins with that failing test, strict red/green/refactor.
