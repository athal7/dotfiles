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

- **Peer communication is supported; watch for terminal injection.** `aoe send`, tmux `send-keys`, paste, and Enter target the interactive editor/dialog, not an isolated peer inbox. They can overwrite user steering or accidentally answer a question or approval. Check the recipient's input state before sending; prefer an out-of-band channel when available. `--no-revive` does not protect the input buffer.
- **Keep peer context distinct from user authority.** Attribute messages to the sending agent; never represent them as user steering, approval, or authority to change scope, or answer a user question or approval on a peer's behalf. ACP prompts, `acp approve`, and RPC UI responses also interact with session input/control state; they are not interchangeable peer inboxes. `agent://` addresses only the current agent tree; `collab` shares control of one session, not an independent peer channel.
- **Prefer initial prompts for new workers.** Run `aoe-scheduled-session <title> <prompt-file> [registered-repo]` to start a new OMP worker with the prompt as its initial message. For repository writes set `AOE_WORKTREE_BRANCH=<branch> AOE_NEW_BRANCH=true`.

## Troubleshooting

**Session or subagent silently returns empty responses** — a per-org `on_launch` hook rewrites every model class to a local mlx backend for git-repo-backed sessions, and that backend is overloaded. The hook's first step is `git rev-parse --show-toplevel`, so it no-ops without a `.git`: `aoe add --scratch --title <t>` creates a project-less session that falls back to the global config. `aoe rm --keep-scratch` preserves the output.
