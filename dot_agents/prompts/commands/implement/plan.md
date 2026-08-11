1. Gather internal context — source, history, the issue, constraining specs.
2. Research unfamiliar libraries or APIs — load `source-driven-development`; dispatch `scout` when an isolated pass helps, otherwise do it directly.
3. Work the request against the context and the spec constraints — "what should change and why?" With `edit`/`write` tools available in this session, planning/design work can be done directly; without them (or when the analysis genuinely benefits from an isolated pass — a competing-alternatives comparison, a large unfamiliar codebase), dispatch `planner` instead. Either way, load `incremental-implementation` for the over-designing checklist, and apply the same discipline: **Recommendation** (upfront, 1-2 sentences) → **Reasoning** (cite `file:line`) → **Spec constraints** → **Tradeoffs considered** → **Open questions**.

**Persist it as an OpenSpec proposal** via `openspec-propose` — proposal, design, tasks. Mandatory regardless of size. If the plan's Domain model proposes new or changed terms, write them to `changes/<name>/specs/domain-model/spec.md`: one Requirement per term (`Term: <X>` / `Bounded context: <X>`) with a `#### Scenario:` giving its canonical meaning and boundary, valid under `openspec validate`.

`openspec/` is real but not throwaway. Only `specs` and `changes/archive` are gitignored symlinks into the store; in-flight `changes/<name>/` are deliberately tracked so they show up in review. Never `git add` those two symlinks, and never blanket-add in-flight change files into a code commit.

**Present the proposal. Wait.**

Ends with: an approved proposal.
