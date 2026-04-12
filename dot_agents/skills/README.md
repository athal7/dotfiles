# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills for AI agents. Works with OpenCode.

## Skills

| Integration | Workflow |
|-------------|----------|
| **elasticsearch** — Query ES logs, APM traces, and errors via curl | **architecture** — Architecture decisions and code-level design smell analysis |
| **figma** — Read Figma files, components, variables, and projects | **attention** — Energy and spoon check, surface NOW/NEXT/LATER |
| **gh-pr-inline** — Post inline comments on GitHub PRs via `gh api` | **audit** — Review and optimize agent instructions, skills, and commands |
| **linear** — Query and update Linear issues and projects | **chezmoi-apply** — Run `chezmoi apply` safely from inside OpenCode |
| **slack** — Send messages, search conversations, read threads | **cleanup** — Reclaim disk space: worktrees, databases, Docker |
| | **commit** — Semantic commit format, branch naming, squashing |
| | **context-log** — Maintain `.opencode/context-log.md` across sessions |
| | **conversations** — Research people and decisions across Slack, meetings, Gmail |
| | **dispatch** — Spawn or reuse an OpenCode session in another workspace |
| | **learn** — Extract non-obvious learnings into AGENTS.md or new skills |
| | **observability** — Investigate production issues using logs and traces |
| | **opencode-repair** — Fix blank sessions, missing worktrees, DB issues |
| | **pr-stack** — Manage stacked/dependent PRs with git-spice |
| | **process** — Enforced plan → review → implement → verify → commit workflow |
| | **pty** — PTY sessions for long-running or interactive processes |
| | **push** — Push approval protocol and CI watching |
| | **qa** — Browser QA verification via Firefox DevTools |
| | **reset-diff** — Fix stale Modified Files sidebar after rebase or merge |
| | **review** — Review changes: commit, branch, PR, or staged |
| | **session-history** — Read and search OpenCode session history |
| | **tdd** — Strict red/green/refactor TDD loop |
| | **thinking-tools** — Structured frameworks for decisions and problem framing |
| | **todo** — Add to todo list without interrupting current work |
| | **writing** — Write tickets, PRDs, project updates, and ADRs |

## Install via chezmoi external

Add to your `.chezmoiexternal.toml`:

```toml
[".agents/skills"]
  type = "archive"
  url = "https://github.com/athal7/dotfiles/archive/refs/heads/main.tar.gz"
  stripComponents = 3
  include = ["*/dot_agents/skills/**"]
```

## Roadmap

A dedicated public skills repo is planned. This directory will become a subset of that registry.
