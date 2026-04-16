# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills for AI agents. Works with [OpenCode](https://opencode.ai) and any compatible agent.

See the [dotfiles README](../../README.md) for install instructions, the capability composition system, and the [proposed spec extension](https://github.com/agentskills/agentskills/discussions/311) that powers it.

## Skills

Capabilities backed by a CLI (`cli://`) don't have a skill — the agent reads `--help` on demand. Capabilities backed by a skill carry non-obvious usage knowledge that `--help` doesn't surface.

| Integration (skill) | Workflow |
|---------------------|----------|
| **elasticsearch** — Query ES logs, APM traces, and errors via curl | **architecture** — Architecture decisions and code-level design smell analysis |
| **figma** — Read Figma files, components, variables, and projects | **attention** — Energy and spoon check, surface NOW/NEXT/LATER |
| **gh-pr-inline** — Post inline comments on GitHub PRs via `gh api` | **audit** — Review and optimize agent instructions, skills, and commands |
| **remindctl** — Read and write Apple Reminders (timezone gotcha, recurrence gap) | **chezmoi-apply** — Run `chezmoi apply` safely from inside OpenCode |
| **slack** — Send messages, search conversations, read threads | **cleanup** — Reclaim disk space: worktrees, databases, Docker |
| **opencode** — Sessions, dispatch, repair, and diff reset for the OpenCode runtime | **commit** — Semantic commit format, branch naming, squashing |
| | **context-log** — Maintain `.opencode/context-log.md` across sessions |
| | **conversations** — Research people and decisions across Slack, meetings, Gmail |
| | **learn** — Extract non-obvious learnings into AGENTS.md or new skills |
| | **observability** — Investigate production issues using logs and traces |
| | **pr-stack** — Manage stacked/dependent PRs with git-spice |
| | **plan** — Present a plan and wait for approval before implementing |
| | **pty** — PTY sessions for long-running or interactive processes |
| | **push** — Push approval protocol and CI watching |
| | **qa** — Browser QA verification via Firefox DevTools |
| | **review** — Review changes: commit, branch, PR, or staged |
| | **tdd** — Strict red/green/refactor TDD loop |
| | **thinking-tools** — Structured frameworks for decisions and problem framing |
| | **todo** — Add to todo list without interrupting current work |
| | **writing** — Write tickets, PRDs, project updates, and ADRs |
