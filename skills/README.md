# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills for AI agents. Works with [OpenCode](https://opencode.ai) and any compatible agent.

See the [dotfiles README](../README.md) for install instructions, the capability composition system, and the [proposed spec extension](https://github.com/agentskills/agentskills/discussions/311) that powers it.

## Skills

Capabilities backed by a CLI (`cli://`) don't have a skill — the agent reads `--help` on demand. Capabilities backed by a skill carry non-obvious usage knowledge that `--help` doesn't surface.

| Integration (skill) | Workflow |
|---------------------|----------|
| **elasticsearch** — Query ES logs, APM traces, and errors via curl | **architecture** — Architecture decisions, design prerequisite check, ADR template |
| **figma** — Read Figma files, components, variables, and projects | **attention** — Energy and spoon check, surface NOW/NEXT/LATER |
| **gh** — GitHub CLI integration: merge requests, CI, inline comments | **chezmoi** — Manage dotfiles via chezmoi |
| **docs** — Read/write Google Docs and Confluence | **commit** — Semantic commit format, branch naming, squashing |
| **slack** — Send messages, search conversations, read threads | **context-log** — Maintain `.opencode/context-log.md` across sessions |
| **opencode** — Sessions, dispatch, repair, and diff reset for the OpenCode runtime | **conversations** — Research people and decisions across chat, meetings, email |
| **pty** — PTY sessions for long-running or interactive processes | **issues** — Route to Linear or GitHub Issues based on org |
| **secrets** — Fetch credentials and API keys | **observability** — Investigate production issues using logs and traces |
| | **post-meeting** — Post-recording meeting processing |
| | **push** — Push approval protocol and CI watching |
| | **qa** — Browser QA verification via Firefox DevTools |
| | **respond-to-review** — Address review feedback on a merge request |
| | **review** — Review changes: commit, branch, merge request, or staged |
| | **code-quality** — Code quality reference: design patterns, smells, anti-patterns |
| | **thinking-tools** — Structured frameworks for decisions and problem framing |

External skills (installed via `gh skill install` from upstream maintainers) — see `.chezmoidata/packages.yaml` `skills:` block:

- **ical-cli** ([BRO3886/ical](https://github.com/BRO3886/ical)) — macOS Calendar from the terminal
- **linear-cli** ([schpet/linear-cli](https://github.com/schpet/linear-cli)) — Linear issues from the terminal

## Beyond skills

Two parts of the workflow are *not* skills, by design — see `skills/AGENTS.md` for when to pick which primitive.

- **TDD** lives in `dot_config/opencode/tdd.md` and is loaded into every session via `instructions:`. The trigger ("every code change") is continuous, not a discrete moment, so a skill would underperform — and the data showed it did.
- **Plan** is the built-in OpenCode plan agent (Tab to enter). It's a mode with its own permission profile, not a skill — the platform enforces read-only and gates writes through `ask`.

## Commands

User-triggered slash commands that package self-contained workflows. Invoke with `/name`.

| Command | Description |
|---------|-------------|
| **/learn** | Capture non-obvious discoveries from this session into AGENTS.md or a new skill |
| **/audit** | Five-phase audit of the agent system — load rates, capability layer health, frontmatter, content, primitive fit |
| **/cleanup** | Reclaim disk space — stale worktrees, PostgreSQL databases, OpenCode DB entries |
| **/todo** | Add to todo list without interrupting current work |

## Spec extension watchlist

This repo solo-extends the agentskills spec via a capabilities manifest (`requires`/`provides` + `capabilities.yaml`). Several open proposals would let parts of that move upstream. Re-check during each `/audit`.

| Issue | What it would change for us |
|---|---|
| [agentskills #110](https://github.com/agentskills/agentskills/issues/110) — Skill dependencies + version | Native `requires:` for inter-skill dependencies. Would replace the `requires:` half of our manifest. |
| [agentskills #330](https://github.com/agentskills/agentskills/issues/330) — Tool dependencies | Spec-level way to declare CLI/tool requirements per skill. Adjacent to our `provides: cli://` pattern. |
| [agentskills #111](https://github.com/agentskills/agentskills/issues/111) — `agents:` field (closed) | Per-agent skill scoping in frontmatter. Would have replaced our (now-removed) per-agent permission scoping if it had landed. |
| [agentskills #129](https://github.com/agentskills/agentskills/issues/129) — Sub-agent + skill interop (closed) | Strategic-direction thread on how subagents reference skills. Worth tracking even though closed. |
| [anthropics/claude-code #44952](https://github.com/anthropics/claude-code/issues/44952) — Per-agent skill scoping | Same problem in Claude Code. If they ship something portable, we adopt. |
| [anomalyco/opencode #21793](https://github.com/anomalyco/opencode/issues/21793) — `permission.skill` patterns not enforced | Open bug. If we ever re-add per-agent skill scoping, this needs to ship first. |
