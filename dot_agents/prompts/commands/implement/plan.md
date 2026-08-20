1. Gather internal context — source, history, the issue, and recorded decisions.
2. Research unfamiliar libraries or APIs with `mcp__context_resolve_library_id` followed by `mcp__context_query_docs`; use official documentation and cite the source that constrains the plan.
3. Work the request against the context and constraints — "what should change and why?" With `edit`/`write` tools available in this session, planning/design work can be done directly; without them (or when the analysis genuinely benefits from an isolated pass — a competing-alternatives comparison, a large unfamiliar codebase), dispatch `planner` instead. Define the smallest independently verifiable increments; every increment above the stated requirement must earn its place in the Reasoning. Return **Recommendation** (upfront, 1-2 sentences) → **Reasoning** (cite `file:line`) → **Constraints** → **Tradeoffs considered** → **Open questions**.

**Present the plan. Wait.**

Ends with: an approved plan.
