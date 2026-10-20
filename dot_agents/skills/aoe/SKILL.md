---
name: aoe
description: "Agent of Empires (aoe) — the session-orchestration CLI: create, dispatch to, and manage OMP sessions (worktrees, aoe add/send/session attach/capture, scratch sessions)."
license: MIT
---

`aoe` creates and drives agent sessions. **Run `aoe --help` and `aoe <subcommand> --help`** — flags change between releases; this file covers only what help text won't tell you.

- **`add` then `session start` are two calls.** `aoe add <path> --title <t>` creates the record; `aoe session start <id>` starts the worker. `aoe add --launch` tries to attach interactively and fails in any non-TTY context (scripts, LaunchAgents).
- **Sleep ~5s after `session start` before the first `send`.** The TUI takes seconds to boot; an early `send` is silently dropped and still reports success.
- **Every session and subagent that may modify a repository needs a dedicated git worktree.** Read-only inspection needs neither a new session nor a worktree. Use `aoe add <registered-path> --worktree <branch> --new-branch` (plus `--base-branch` when needed); for an existing session, `aoe session add-project <session> <project>` creates a worktree but restarts the agent. If attachment is refused because its conversation is bound to the current directory, use a new session; never clear the resume target or proceed without write isolation.
- **`<path>` is canonicalized, never resolved back to the main repo.** Point `aoe add` at a worktree and it silently creates a bogus project rooted there. Pass the exact registered path (`aoe project list`) plus `--worktree`. `--project`/`--repo` add *extra* repos to a multi-repo workspace — they don't select the primary target.
- **`send` is fire-and-forget.** No wait verb. Check back with `aoe session capture <id>` or attach. One task per session — check `aoe list` before starting overlapping work.

## Troubleshooting

**Session or subagent silently returns empty responses** — a per-org `on_launch` hook rewrites every model class to a local mlx backend for git-repo-backed sessions, and that backend is overloaded. The hook's first step is `git rev-parse --show-toplevel`, so it no-ops without a `.git`: `aoe add --scratch --title <t>` creates a project-less session that falls back to the global config. `aoe rm --keep-scratch` preserves the output.
