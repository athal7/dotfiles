# Prior Attempts at Workflow Enforcement

This document records what was tried, what was measured, and what was
learned. Each attempt taught something. The pattern is: each solution
addressed the previous failure mode but introduced a new one.

## Attempt 1: Specialized Agents (January 2026)

**Commits:** `55d8d5c` (review agent), `86bc58e` (QA agent fix),
`91db700` (parallel specialist reviewers), `a0af9ee` (local agents)

**What it did:** Created dedicated subagents for specific tasks:
- Review agent (claude-sonnet with thinking, Context7 access)
- QA agent (browser-based verification)
- Architecture agent (opus for deep analysis)
- Four parallel review specialists (security, correctness, performance, maintainability)
- Local router agent (llama.cpp Qwen3-4B for triage)

At peak: 8+ agent definitions in the config.

**What it was trying to solve:** The primary agent doing everything
itself and not applying specialist thinking to review, QA, or
architecture decisions.

**What was measured:** Custom subagents with separate models dominated
wall time because each had to reload context from scratch. The local
router was unstable. Review specialists were consolidated back into
a single expert agent (`ce3cb11`), then the expert was removed
entirely (`732d056`).

**Why it failed:** More agents ≠ better workflow. Each agent boundary
is a context cliff — the subagent starts cold, must be fed all relevant
context in the dispatch prompt, and returns a single summary. For review
specialists, the overhead of 4 parallel cold starts exceeded the value
of parallelism. The router agent added latency without improving
routing quality.

**Lesson:** Agent boundaries are expensive. Only create them when the
structural constraint (different permissions, different tools) justifies
the context cost. Don't split for specialization alone — skills handle
that without the cold-start penalty.

## Attempt 2: MCP Consolidation (January 2026)

**Commits:** `d41049f` (replace individual MCPs with team-context-mcp),
`658710e` (native playwright transport), `26fcddc` (native HTTP/MCP)

**What it did:** Replaced 3 individual MCP servers (figma, granola,
elasticsearch) and their corresponding specialized agents (context,
observability, PM, UX) with a single team-context-mcp on port 8100.
Also removed supergateway SSE wrappers in favor of native MCP transport.

**What it was trying to solve:** MCP sprawl — each service had its own
LaunchAgent, its own port, its own agent wrapper. Configuration was
fragile and debugging was hard.

**Outcome:** Reduced from 3 MCP servers + 4 specialized agents to 1 MCP
server. Simpler, more reliable. But this was an infrastructure
simplification, not a workflow enforcement change.

**Lesson:** Consolidate infrastructure aggressively. Each running service
is a failure point. Prefer fewer, more capable servers over many small ones.

## Attempt 3: Agent Simplification (January 2026)

**Commits:** `2ff0798` (simplify agent structure), `9773f31` (remove
local ollama agents), `514efa9` (remove commands)

**What it did:** Deleted architect, docs, QA, and review agents.
Converted QA and review from subagents to enhanced commands. Slimmed
build.md from 164 to 71 lines. Merged architect into plan.md. Added
"bloat prevention guidelines."

**What it was trying to solve:** Agent proliferation from Attempt 1.
Too many agents, too much configuration, compliance was worse not better.

**What was measured:** After simplification, compliance improved — fewer
moving parts meant the primary agent could actually follow the workflow
without getting lost dispatching to specialists.

**Lesson:** Simplification works. Fewer agents with clearer roles
outperform many agents with narrow specializations. This is the same
lesson as the orchestrator skill failure — more structure ≠ more
compliance.

## Attempt 4: Mandatory Review in Build Agent (January 2026)

**Commit:** `8f2bad9` — "add mandatory review cycle before push in build agent"

**What it did:** Added 6 lines to build.md making review a required step
before push.

**What it was trying to solve:** Review being skipped.

**Why it failed:** Advisory instruction in a prompt. The build agent
could and did skip it. Same failure mode as putting workflow rules in
AGENTS.md — the agent treats it as a suggestion.

**Lesson:** "Mandatory" in prose is not mandatory in practice.

## Attempt 5: Process Skill — The Orchestrator (March 2026)

**Commits:** `2bf730c` (create process skill), `29e7688` (fold
context-log and learn into process)

**What it did:** Created a 121-line "process" skill with a 7-phase
workflow: Plan → Expert Review → User Approval → Implement → Verify →
User Approval → Commit. Declared 10 required capabilities. Included
skip criteria for trivial changes. Later absorbed context-log and learn
as sub-files.

**What it was trying to solve:** Workflow steps being skipped when they
lived as prose in AGENTS.md. The theory was that a dedicated skill with
explicit gates would enforce the sequence.

**What was measured:** Across 69 sessions where the process skill was
loaded: TDD compliance fell from 34% to 9%. Architecture capability
loading fell from 26% to 7%. The orchestrator actively suppressed the
capabilities it wrapped.

**Why it failed:** The agent reads long phase graphs as menus, not
imperatives. Action phases (implement, commit, push) get executed;
deliberative phases (plan, verify, capture) get skipped. Required
capabilities listed in frontmatter were followed at ~4% rate per hop of
indirection.

**Lesson:** One skill = one trigger = one moment. Phase graphs suppress
rather than enforce. Continuous behaviors (TDD) need to be always-loaded
instructions, not optional skills.

## Attempt 6: TDD as Instructions File (May 3, 2026)

**Commit:** `483b807` — "relocate tdd to instructions, eliminate plan skill"

**What it did:** Moved TDD from a skill (loaded on demand) to an
always-loaded instructions file via opencode's `instructions:` array.
TDD guidance present in every session without the agent choosing to load
it. Also eliminated the plan skill (redundant with built-in plan agent).

**What it was trying to solve:** TDD compliance collapsing from 34% to
9% under the process skill orchestrator. TDD has a continuous trigger
(every code change), not a concrete moment — wrong primitive.

**Outcome:** TDD guidance was always-present. But the instructions file
was silently not loading due to a path resolution bug (relative paths
resolve against cwd, not config dir). Discovered and fixed in `006e35d`.

**Lesson:** Always-loaded instructions are the right primitive for
continuous behaviors. But verify they actually load — silent failures
in config are invisible.

## Attempt 7: Enforcer Identity (April 27, 2026)

**Commit:** `a8b1983` — "reframe delegation as enforcer identity"

**What it did:** Changed the primary agent's AGENTS.md from a
task-scoped directive ("delegate implementation to sub-agents") to a
role declaration ("you are the process enforcer, all work dispatches
to sub-agents with no exceptions").

**What it was trying to solve:** The primary agent still doing
implementation itself despite delegation rules. Measured: 62.5% of
edit-bearing sessions violated the delegation rule.

**What was measured (before):** 62.5% delegation violation rate.

**Why it failed:** Identity framing is still advisory. The agent adopted
the "enforcer" language but still edited files directly when it seemed
efficient. Prose identity doesn't override tool availability.

**Lesson:** You can't talk an agent out of using tools it has access to.
If the tool exists, the agent will use it when the task seems to call
for it, regardless of identity framing.

## Attempt 8: Gates Plugin — Mechanical Enforcement (April 30, 2026)

**Commits:** `aa41ce5` (create gates plugin), `d8ad8cf` (make config-driven)

**What it did:** Built a 319-line TypeScript plugin that maintained
per-repo, per-branch state in `~/.local/state/opencode/gates/`. Three
gates: plan approval (blocks edit/write), commit approval (blocks git
commit), push approval (blocks git push). Each gate required the user to
answer a Question tool prompt. State persisted across sessions. Had 305
lines of bun:test coverage.

**What it was trying to solve:** All previous advisory approaches failed.
This made gates mechanical — the plugin intercepted tool calls and
blocked them until the gate was passed.

**What was measured:** Not measured in production — replaced after one day.

**Why it was replaced:** opencode shipped native permission config
(`permission.bash` with allow/ask/deny patterns) the same week. The
gates plugin reinvented what the platform now provided natively.

**Commit:** `73e6b52` — "replace gates plugin with opencode permission config"
Deleted 886 lines (plugin + tests). Replaced with per-package permission
patterns in packages.yaml.

**Lesson:** Don't build bespoke enforcement when the platform provides
native primitives. But the gates plugin proved that mechanical
enforcement works — the concept was right, the implementation was wrong
(bespoke instead of native).

## Attempt 9: Permission-Based Enforcement (May 1, 2026)

**Commit:** `73e6b52` — "replace gates plugin with opencode permission config"

**What it did:** Declared per-package permission patterns in
packages.yaml: read operations → allow, write operations → ask. Applied
to git, gh, chezmoi, linear, and other CLIs.

**What it was trying to solve:** Replacing the bespoke gates plugin with
native platform enforcement.

**What was measured:** `git commit` and `git push` consistently prompt
for approval. Read operations flow without interruption.

**What it didn't solve:** Permission gates enforce individual operations
but don't compose into sequences. The human sees "allow git commit?" but
has no structural assurance that review happened first. The 85% review
skip rate persisted.

**Lesson:** Permissions are the strongest enforcement primitive for
individual operations but don't compose into workflow sequences.

## Attempt 10: Three-Agent Topology (May 14, 2026)

**Commits:** `0a0bc12` (three-agent topology), `006e35d` (drift repair)

**What it did:** Split from one agent into three:
- Lead (primary): orchestrates, dispatches, verifies. No edit/write.
- Plan (subagent): deep analysis. Read-only.
- Build (subagent): TDD implementation. Has edit/write, steps=30.

Lead can't edit files — structurally impossible.

**What it was trying to solve:** Lead doing implementation itself.
Measured: 62.5% delegation violation rate. Removing edit/write tools
makes violation structurally impossible.

**What was measured:** Lead no longer edits (structurally can't). Build
follows TDD at higher rates (in the prompt, not a separate skill to
load). But lead still loads commit 84x, review 69x, push 41x — doing
all shipping work itself.

**What it didn't solve:** The topology enforces delegation for building
but not for shipping. Review is still a skill lead must choose to load,
and it skips review 85% of the time.

**Lesson:** Structural enforcement (removing tools) works precisely for
the behavior it targets. Each enforcement is narrow — you prevent exactly
what you structurally prevent, nothing more.

## Attempt 11: Skill Injection (May 19, 2026)

**Commits:** `fd2e5f3` (config-driven injection), `bea122d` (remove
capability references), `c6b3e78` (simplify workflows)

**What it did:** Replaced the frontmatter capability system (skills
declaring requires/provides, ~4% follow-through) with a config-driven
injection plugin. When a skill loads, the plugin appends references to
related skills. Also simplified commit/review/push skills.

**What it was trying to solve:** Skills declaring dependencies that
weren't being followed. Config-driven injection makes wiring explicit
and automatic.

**What was measured:** Injection works — loading review automatically
surfaces qa, gh, code-quality references. But injection surfaces
references, not imperatives. The agent sees "Related skills: qa,
code-quality" and may or may not load them.

**What it didn't solve:** The fundamental problem: review must happen
before commit, and no primitive enforces that sequence.

## Attempt 12: Compaction Reinforcement (May 14, 2026)

**Commit:** `006e35d` — "repair review/tone/issue discipline drift"

**What it did:** Extended the compaction plugin's continuation rules to
reinforce review/commit/push discipline after context compaction.

**What was measured (from commit skill audit):** 60% of commit-time
sessions still skipped the review verification gate despite it being a
"STOP" instruction. Led to strengthening the commit skill's verification
gate to a "refusal-shaped opener."

**What it didn't solve:** Compaction rules are advisory — same as any
other prompt content. Better right after compaction, drifts as session
continues.

**Lesson:** Post-compaction injection is the right mechanism for
re-establishing context. But it's still advisory.

## The Pattern

```
Specialized agents (8+ agents)
    ↓ FAILED: context cliffs, cold start overhead, wall time
Agent simplification (fewer agents)
    ↓ WORKED: fewer agents = better compliance
Mandatory review in build prompt
    ↓ FAILED: advisory, skipped
Process skill (7-phase orchestrator)
    ↓ FAILED: TDD 34%→9%, arch 26%→7%, menus not imperatives
TDD as instructions (always-loaded)
    ↓ WORKED: right primitive for continuous behavior
Enforcer identity (role declaration)
    ↓ FAILED: prose identity doesn't override tool availability
Gates plugin (mechanical enforcement)
    ↓ WORKED conceptually, REPLACED by native permissions
Permission config (allow/ask/deny)
    ↓ WORKS for individual ops, DOESN'T compose into sequences
Three-agent topology (structural delegation)
    ↓ WORKS for edit delegation, review still skipped 85%
Skill injection (auto-surface related skills)
    ↓ Surfaces references, not imperatives
Compaction reinforcement (re-inject rules)
    ↓ Helps briefly, still advisory, still drifts
```

## Measured Metrics Across Eras

Data from the opencode session database (1,965 top-level sessions, Jan 5 - May 26 2026).

| Era | Sessions | Code Sessions | Review/Commit | Commit/Code | Push/Commit | Thinking | Delegation | Avg Skills |
|-----|----------|---------------|--------------|-------------|-------------|----------|------------|------------|
| A: Specialized (Jan 5-23) | 240 | 86 | 0% | 0% | 0% | 0% | 38% | 0.0 |
| B: Simplified (Jan 23-Mar 24) | 879 | 357 | 12% | 59% | 51% | 0% | 73% | 0.6 |
| C: Process skill (Mar 24-May 1) | 583 | 299 | 22% | 62% | 87% | 7% | 64% | 2.3 |
| D: Permissions (May 1-14) | 138 | 68 | 37% | 75% | 75% | 1% | 25% | 2.1 |
| E: Three-agent (May 14-19) | 47 | 32 | 75% | 100% | 66% | 13% | 100% | 4.8 |
| F: Current (May 19+) | 78 | 51 | 80% | 80% | 39% | 12% | 94% | 4.3 |

**Column definitions:**
- **Review/Commit**: Of sessions that loaded commit skill, what % also loaded review? (The core compliance metric.)
- **Commit/Code**: Of sessions with code changes, what % loaded the commit skill?
- **Push/Commit**: Of sessions that committed, what % loaded push?
- **Thinking**: % of all sessions that loaded architecture or thinking-tools.
- **Delegation**: Of code-change sessions (excluding dotfiles repo), what % dispatched to a subagent? (Dotfiles excluded because config was actively being iterated.)
- **Avg Skills**: Average distinct skills loaded per session.

**Key observations:**

1. **Review compliance improved dramatically with the three-agent topology** (Era E: 75%, Era F: 80%) compared to earlier eras (A-C: 0-22%). The structural change of removing edit/write from lead forced a workflow where lead orchestrates rather than implements, and this incidentally improved review loading.

2. **The process skill era (C) shows modest review improvement** (22% vs 12% in era B) but at the cost of loading 2.3 skills per session. The skill-loading overhead increased without proportional compliance gains.

3. **Delegation rate collapsed in the permissions era (D)** from 64% to 25%. The permission config added friction to every bash command, which may have discouraged subagent dispatch (subagents inherit the same friction).

4. **Era A had zero skill loads** — skills weren't yet part of the system. The specialized agents approach used dedicated agent prompts instead.

5. **Push compliance peaked during the process skill era (C)** at 87% and has been declining since. Currently at 39% in era F.

6. **Thinking skill adoption is low across all eras** (max 13% in era E). Architecture and thinking-tools are rarely loaded regardless of what other changes are made.

## What Works

- **Removing tools from agents** — lead can't edit → lead doesn't edit
- **Permission ask/deny on individual operations** — commit needs approval
- **Always-loaded instructions for continuous behaviors** — TDD in build prompt
- **Fewer agents with clearer roles** — 3 agents > 8 agents
- **Simplification** — shorter prompts, fewer skills, less indirection

## What Doesn't Work

- **Phase-graph skills** — suppresses rather than enforces
- **Advisory guidance in any form** — prose, identity framing, "mandatory" labels
- **Long instruction sets** — attention budget degradation
- **Indirection** ("load this other skill") — ~4% follow-through per hop
- **More agents for specialization** — context cliffs dominate
- **Bespoke enforcement** — fragile, hard to maintain, gets replaced

## The Unsolved Problem

How to make a multi-step sequence (review then commit) structurally
inevitable, not just advised. The platform provides permission gates on
individual operations but no primitive for "step A must precede step B."
