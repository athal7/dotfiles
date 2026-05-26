## Context

The agent system has evolved through 12 iterations (see prior-attempts.md)
seeking reliable workflow enforcement. The current system uses a three-agent
topology (lead/plan/build) with permission-based enforcement and moment-
triggered skills. Measured across 1,965 sessions, review compliance reached
80% — the best era yet — but 20% non-compliance persists and advisory
approaches consistently fail.

Four workflow specs define the desired state:
- `agent-workflow` — implement changes via plan/build/review/ship
- `code-review` — review someone else's merge request
- `merge-request` — maintain your own MR (feedback, conflicts, rebase)
- `remote-operations` — reads allowed, writes need approval

## Goals / Non-Goals

**Goals:**
- Map the harness capabilities required by all four specs
- Identify gaps between current capabilities and what's needed
- Research existing tools to fill gaps before building bespoke
- Design a solution grounded in measured evidence of what works

**Non-Goals:**
- Redesigning the agent topology (three-agent split is proven)
- Building bespoke enforcement when platform primitives exist
- Achieving 100% compliance on requirements that can only be advisory
- Adding more agents, more skills, or more instructions

## Harness Capability Map

### Working Well

| Capability | What it does | Mechanism | Confidence |
|---|---|---|---|
| Remote-ops policy | Reads allowed, writes ask | Permission config (packages.yaml) | HIGH — structural |
| Agent topology | Lead orchestrates, plan thinks, build implements | Agent definitions with tool removal | HIGH — structural |
| Tool-level permissions | Individual operations gated | allow/ask/deny per command | HIGH — structural |
| Attention budget | Right guidance at right moment | Short prompts, moment-triggered skills | HIGH — by design |
| TDD enforcement | Build follows red/green/refactor | Always-loaded in build.md prompt | HIGH — right primitive |
| Thread triage | Read all threads before acting | respond-to-review skill (28 lines) | HIGH — well-shaped skill |
| Multi-pass review | Specialist lenses on code | review skill with ordered passes | HIGH — well-shaped skill |

### Partially Working

| Capability | What it does | Current mechanism | Gap |
|---|---|---|---|
| Context gathering | Assemble relevant context before action | Advisory in lead prompt | No structural guarantee context is gathered. Agent can skip to action. |
| Human gates | Approval at defined points | Permission ask on tool calls + advisory prompt | Permission shows command, not content. Plan approval is purely advisory. |
| QA verification | Browser-based UI testing | Firefox DevTools MCP + qa skill | Triggering is advisory. No data on actual QA compliance. |
| Measurement | Know if harness is working | Manual SQL against session DB | No automated trending, alerts, or dashboards. |

### Gaps

| Capability | What it does | Needed by | Current state |
|---|---|---|---|
| Workflow routing | Know which workflow the user wants | All | Implicit — agent infers from phrasing. No explicit entry points for code-review or merge-request workflows. |
| Phase sequencing | Enforce step A before step B | All | Advisory only. 12 attempts have failed to solve this. No platform primitive for sequence gates. |
| Proactive skill delivery | Push guidance based on what's happening | All | Agent-initiated only. Agent must choose to load skills. 20% non-compliance on review loading. |
| Workflow state persistence | Track phase, approvals, findings across compaction | All | In-context only. Compaction loses workflow state. Context-log is general-purpose, not workflow-aware. |
| Feedback loop routing | Route findings to right phase (build vs plan vs human) | Implement | Advisory. Agent tends to either fix everything locally or restart. No structured routing. |
| Drift detection | Agent checks work against intent | All | Advisory. No midpoint-check hook. Thinking skills at 12% adoption. |
| Conflict resolution | Intent-preserving merge conflict resolution | MR | No support. No skill, no instructions. |
| Thread-level tracking | Track per-thread status across fix cycle | MR | In-context only. Lost on compaction. No TodoWrite integration. |

## Decisions

_Pending ecosystem research. Before making implementation decisions, need
to understand what tools exist to address the gaps above. Key questions:_

1. _Does the opencode plugin API support checking session state (which
   skills were loaded) from a `tool.execute.before` hook?_
2. _Are there community plugins or patterns for workflow sequencing?_
3. _Does opencode's roadmap include any of: sequence gates, proactive
   skill delivery, workflow state tracking?_
4. _What do other agent harness tools (Cursor rules, Claude Code hooks,
   Windsurf, etc.) do for workflow enforcement?_
5. _Can OpenSpec's change workflow itself serve as workflow state
   persistence (proposal as plan artifact, tasks as progress tracker)?_

## Risks / Trade-offs

### Advisory gaps are real but bounded
Some requirements (analytical framework application, self-steering,
full-content approval preview) cannot be structurally enforced with
current primitives. The prior-attempts history shows advisory approaches
fail. Accepting these gaps honestly is better than pretending prompt
changes will work.

### Simplification works, complexity doesn't
The measured data shows: fewer agents = better compliance, shorter
prompts = better compliance, concrete-trigger skills = better adoption.
Any solution that adds complexity (more agents, more skills, longer
prompts, orchestrator patterns) is predicted to fail by the data.

### The three hardest gaps are interconnected
Phase sequencing, proactive skill delivery, and workflow state
persistence form a cluster. Solving workflow state could enable the
other two: if the system tracks "build complete, review pending," it
could enforce sequencing (refuse commit until review) and deliver
skills proactively (push review guidance at the right moment).
