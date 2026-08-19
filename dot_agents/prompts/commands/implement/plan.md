1. Gather internal context — source, history, the issue, and recorded decisions.
2. Research unfamiliar libraries or APIs — load `source-driven-development`; dispatch `scout` when an isolated pass helps, otherwise do it directly.
3. Work the request against the context and constraints — "what should change and why?" With `edit`/`write` tools available in this session, planning/design work can be done directly; without them (or when the analysis genuinely benefits from an isolated pass — a competing-alternatives comparison, a large unfamiliar codebase), dispatch `planner` instead. Either way, load `incremental-implementation` for the over-designing checklist, and apply the same discipline: **Recommendation** (upfront, 1-2 sentences) → **Reasoning** (cite `file:line`) → **Constraints** → **Tradeoffs considered** → **Open questions**.

**Present the plan. Wait.**

Ends with: an approved plan.
