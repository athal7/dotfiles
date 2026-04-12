# Agent Skills

[agentskills.io](https://agentskills.io)-compatible skills for AI agents. Works with OpenCode.

## Skills

| Integration | Workflow |
|-------------|----------|
| **elasticsearch** — Query ES logs, APM traces, and errors via curl | **architecture** — Architecture decisions and code-level design smell analysis |
| **figma** — Read Figma files, components, variables, and projects | **attention** — Energy and spoon check, surface NOW/NEXT/LATER |
| **gh-pr-inline** — Post inline comments on GitHub PRs via `gh api` | **audit** — Review and optimize agent instructions, skills, and commands |
| **ical** — Read and write macOS Calendar events via the native EventKit CLI | **chezmoi-apply** — Run `chezmoi apply` safely from inside OpenCode |
| **linear** — Query and update Linear issues and projects | **cleanup** — Reclaim disk space: worktrees, databases, Docker |
| **minutes** — Search and read meeting transcripts via the minutes CLI | **commit** — Semantic commit format, branch naming, squashing |
| **opencode** — Sessions, dispatch, repair, and diff reset for the OpenCode runtime | **context-log** — Maintain `.opencode/context-log.md` across sessions |
| **remindctl** — Read and write Apple Reminders via the native EventKit CLI | **conversations** — Research people and decisions across Slack, meetings, Gmail |
| **slack** — Send messages, search conversations, read threads | **learn** — Extract non-obvious learnings into AGENTS.md or new skills |
| | **observability** — Investigate production issues using logs and traces |
| | **pr-stack** — Manage stacked/dependent PRs with git-spice |
| | **process** — Enforced plan → review → implement → verify → commit workflow |
| | **pty** — PTY sessions for long-running or interactive processes |
| | **push** — Push approval protocol and CI watching |
| | **qa** — Browser QA verification via Firefox DevTools |
| | **review** — Review changes: commit, branch, PR, or staged |
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
