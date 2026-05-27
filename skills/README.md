# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills for AI agents. Works with [OpenCode](https://opencode.ai) and any compatible agent.

The desired system behavior is defined in [workflow specs](../openspec/specs/) — four specs covering implementation, code review, merge request maintenance, and remote operations. Skills and commands implement those specs; [/audit](../dot_config/opencode/commands/audit.md) measures compliance.

## Skills

Integration skills self-register their provided capabilities via `provides` in frontmatter — no manifest needed. Capabilities backed by a skill carry non-obvious usage knowledge that `--help` doesn't surface.

| Integration (skill) | Workflow |
|---------------------|----------|
| **elasticsearch** — Query ES logs, APM traces, and errors | **architecture** — Architecture decisions, design prerequisite check, ADR template |
| **figma** — Read Figma files, components, variables, and projects | **attention** — Energy and spoon check, surface NOW/NEXT/LATER |
| **gh** — GitHub CLI integration: merge requests, CI, inline comments | **chezmoi** — Manage dotfiles via chezmoi |
| **docs** — Read/write Google Docs and Confluence | **commit** — Semantic commit format, branch naming, squashing |
| **opencode** — Sessions, dispatch, repair, and diff reset for the OpenCode runtime | **conversations** — Research people and decisions across chat, meetings, email |
| **pty** — PTY sessions for long-running or interactive processes | **issues** — Route to Linear or GitHub Issues based on org |
| | **observability** — Investigate production issues using logs and traces |
| | **push** — Push approval protocol and CI watching |
| | **qa** — Browser QA verification via Firefox DevTools |
| | **respond-to-review** — Address review feedback on a merge request |
| | **review** — Review changes: commit, branch, merge request, or staged |
| | **code-quality** — Code quality reference: design patterns, smells, anti-patterns |
| | **thinking-tools** — Structured frameworks for decisions and problem framing |

External skills (installed via `gh skill install` from upstream maintainers) — see `.chezmoidata/packages.yaml` `skills:` block:

- **ical-cli** ([BRO3886/ical](https://github.com/BRO3886/ical)) — macOS Calendar from the terminal

## Beyond skills

Some workflow content uses different primitives — see `skills/AGENTS.md` for when to pick which.

- **Workflow commands** (`/implement`, `/review`, `/mr`) embed methodology directly. Review passes, triage workflow, and conflict resolution are always-loaded for the active workflow.
- **TDD** lives in `dot_config/opencode/prompts/build.md`. Continuous trigger → always-loaded in agent prompt.
- **Plan** is a subagent with read-only permissions. Mode-restricted → agent boundary.
- **Specs** (`openspec/specs/`) define desired state. `/audit` measures compliance.

## Commands

Slash commands. Workflow commands embed methodology directly — no skill loading needed.

| Command | Type | Description |
|---------|------|-------------|
| **/implement** | Workflow | Plan/build/review/ship with embedded review passes and approval gates |
| **/review** | Workflow | Code review with multi-pass analysis, QA, finding verification |
| **/mr** | Workflow | Merge request maintenance — triage, fix, conflicts, re-request review |
| **/audit** | Utility | Spec compliance audit — measures against `openspec/specs/` |
| **/learn** | Utility | Capture discoveries into AGENTS.md or a new skill |
| **/cleanup** | Utility | Reclaim disk space — worktrees, databases, temp files |

## Upstream watchlist

Skill dependencies are managed by config-driven injection (`skill-inject.ts`). Per-agent skill scoping is blocked on an upstream bug. Re-check during each `/audit`.

| Issue | What it would change for us |
|---|---|
| [agentskills #110](https://github.com/agentskills/agentskills/issues/110) — Skill dependencies + version | Native `requires:` for inter-skill dependencies. Would replace the `requires:` half of our frontmatter `requires` declarations. |
| [agentskills #330](https://github.com/agentskills/agentskills/issues/330) — Tool dependencies | Spec-level way to declare CLI/tool requirements per skill. Adjacent to our `provides:` + integration skill pattern. |
| [agentskills #111](https://github.com/agentskills/agentskills/issues/111) — `agents:` field (closed) | Per-agent skill scoping in frontmatter. Would have replaced our (now-removed) per-agent permission scoping if it had landed. |
| [agentskills #129](https://github.com/agentskills/agentskills/issues/129) — Sub-agent + skill interop (closed) | Strategic-direction thread on how subagents reference skills. Worth tracking even though closed. |
| [anthropics/claude-code #44952](https://github.com/anthropics/claude-code/issues/44952) — Per-agent skill scoping | Same problem in Claude Code. If they ship something portable, we adopt. |
| [anomalyco/opencode #21793](https://github.com/anomalyco/opencode/issues/21793) — `permission.skill` patterns not enforced | Open bug. If we ever re-add per-agent skill scoping, this needs to ship first. |
