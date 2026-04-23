# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills for AI agents. Works with [OpenCode](https://opencode.ai) and any compatible agent.

See the [dotfiles README](../../README.md) for install instructions, the capability composition system, and the [proposed spec extension](https://github.com/agentskills/agentskills/discussions/311) that powers it.

## Skills

Capabilities backed by a CLI (`cli://`) don't have a skill — the agent reads `--help` on demand. Capabilities backed by a skill carry non-obvious usage knowledge that `--help` doesn't surface.

| Integration (skill) | Workflow |
|---------------------|----------|
| **elasticsearch** — Query ES logs, APM traces, and errors via curl | **architecture** — Architecture decisions and code-level design smell analysis |
| **figma** — Read Figma files, components, variables, and projects | **attention** — Energy and spoon check, surface NOW/NEXT/LATER |
| **gh** — GitHub CLI integration: merge requests, CI, inline comments | **chezmoi-apply** — Run `chezmoi apply` safely from inside OpenCode |
| **google-docs** — Read and write Google Docs via the gws CLI | **commit** — Semantic commit format, branch naming, squashing |
| **slack** — Send messages, search conversations, read threads | **context-log** — Maintain `.opencode/context-log.md` across sessions |
| **opencode** — Sessions, dispatch, repair, and diff reset for the OpenCode runtime | **conversations** — Research people and decisions across chat, meetings, email |
| **pty** — PTY sessions for long-running or interactive processes | **observability** — Investigate production issues using logs and traces |
| | **plan** — Present a plan and wait for approval before implementing |
| | **post-meeting** — Post-recording meeting processing |
| | **push** — Push approval protocol and CI watching |
| | **qa** — Browser QA verification via Firefox DevTools |
| | **review** — Review changes: commit, branch, merge request, or staged |
| | **tdd** — Strict red/green/refactor TDD loop |
| | **thinking-tools** — Structured frameworks for decisions and problem framing |
| | **writing** — Write tickets, PRDs, project updates, and ADRs |

## Commands

User-triggered slash commands that package self-contained workflows. Invoke with `/name`.

| Command | Description |
|---------|-------------|
| **/learn** | Capture non-obvious discoveries from this session into AGENTS.md or a new skill |
| **/audit** | Evaluate agent config — instruction hierarchy, context budget, redundancy, effectiveness |
| **/cleanup** | Reclaim disk space — stale worktrees, PostgreSQL databases, OpenCode DB entries |
| **/todo** | Add to todo list without interrupting current work |
