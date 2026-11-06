---
name: aoe
description: "Use when creating or managing AoE sessions/worktrees, dispatching workers, or communicating with another independent agent session from OMP or Freebuff."
license: MIT
---

`aoe` creates and drives agent sessions. **Run `aoe --help` and `aoe <subcommand> --help`** — flags change between releases; this file covers only what help text won't tell you.

- **Distinguish tmux from structured ACP sessions.** For tmux, `aoe add <path> --title <t>` creates the record and `aoe session start <id>` starts the worker. For ACP, discover supported agents with `aoe acp agents`; `aoe add --scratch --agent omp --title <t>` creates a structured OMP scratch worker served by `aoe serve`. Do not call `session start` on ACP sessions. `aoe add --launch` tries to attach interactively and fails without a TTY.
- **Every session and subagent that may modify a repository needs a dedicated git worktree.** Read-only inspection needs neither a new session nor a worktree. Use `aoe add <registered-path> --worktree <branch> --new-branch` (plus `--base-branch` when needed); for an existing session, `aoe session add-project <session> <project>` creates a worktree but restarts the agent. If attachment is refused because its conversation is bound to the current directory, use a new session; never clear the resume target or proceed without write isolation.
- **`<path>` is canonicalized, never resolved back to the main repo.** Point `aoe add` at a worktree and it silently creates a bogus project rooted there. Pass the exact registered path (`aoe project list`) plus `--worktree`. `--project`/`--repo` add *extra* repos to a multi-repo workspace — they don't select the primary target.
- **Check `aoe list --all --json` before dispatch.** Verify the recipient's ID, profile, and transport; one task per session. Do not restart, convert, cancel, or revive an existing session to deliver a message.

## Peer communication

- **Never use `aoe send`, tmux `send-keys`, paste, or Enter for peer messages or replies.** They target the interactive editor/dialog and can overwrite user steering or answer a question. `--no-revive` does not make delivery safe.
- **Keep user input and approvals separate.** Hold peer messages while a user question, approval, or draft is active; never auto-forward when a session appears idle. Never use ACP prompts, `acp approve`, RPC UI responses, or terminal input as fallbacks. `agent://` addresses only the current agent tree; `collab` shares control of one session, not an independent peer channel.
- **Bootstrap without terminal input.** Run `aoe-scheduled-session <title> <prompt-file> [registered-repo]` to start a new OMP worker with the prompt as its initial message. For repository writes set `AOE_WORKTREE_BRANCH=<branch> AOE_NEW_BRANCH=true`. Startup failure does not authorize a retry or injected fallback.

## Troubleshooting

**Session or subagent silently returns empty responses** — a per-org `on_launch` hook rewrites every model class to a local mlx backend for git-repo-backed sessions, and that backend is overloaded. The hook's first step is `git rev-parse --show-toplevel`, so it no-ops without a `.git`: `aoe add --scratch --title <t>` creates a project-less session that falls back to the global config. `aoe rm --keep-scratch` preserves the output.
