---
name: opencode
description: OpenCode agent runtime — manage sessions, dispatch tasks, answer waiting questions, repair DB issues, and reset diffs
license: MIT
compatibility: opencode
---

Unified skill for all OpenCode agent runtime operations. Use the reference files below for each area.

## Dispatch & coordination

The interface is `opencode-cmd` (raw API at `http://localhost:4096` for reference). **Run `opencode-cmd help` for the full verb/flag reference** — don't restate syntax here.

- **Dispatch in plan mode by default** (`-a plan`): the dispatched session proposes changes and waits for approval. Override the agent only when the task genuinely needs autonomous implementation.
- **Round-trip is the default**: use `ask` (sends, waits, prints the reply) or `await` (collect a reply someone else kicked off) — not fire-and-forget `msg`, which won't return the response.
- **Coordinate before colliding**: before mutating a shared directory, or to find sessions on overlapping concerns, run `peers` — it lists root sessions in the *same git repo* (including sibling worktrees) with busy/idle status. If a peer is busy in your directory, `ask` it to coordinate instead of racing its index/branch state. Covers all three: two sessions colliding in one dir, overlapping tickets across worktrees, and coordinating with an agent in another worktree.
- **Worktrees are mandatory for branch/parallel work**: any task reviewing/modifying a PR branch, or parallel work on the same repo, must run in a worktree — concurrent sessions in one directory clobber each other's checkouts, stashes, and index. Use the `worktree` verb (then `create` + `ask` into it), or `wt-move` to relocate an existing session.
- **`wt-move` self-id caveat**: nothing inside the TUI/Desktop UI can detect its *own* session id (no `$SESSION_ID` command variable, no `OPENCODE_SESSION_ID` env var, no current-session API), so `wt-move` is for scripted/known-id use. The `/worktree` command works around this via a plugin tool that reads `context.sessionID`.
- **One task per session** — don't queue prompts into a busy session.
- **Dispatch the intent, not the decomposition** — send e.g. `Workflow: implement. Linear issue KEY-1234`, not the individual steps; the receiving session has its own AGENTS.md/skills/plan agent to drive. Decomposing from the wrong workspace is the anti-pattern.

`opencode-cmd` is preferred over `opencode run --attach` because it adds dir-scoping, status, worktree, and questions support, and can dispatch to the `plan` subagent — `opencode run --attach --agent plan` cannot (it falls back to the default primary agent).

- **[sessions.md](sessions.md)** — list, search, read, and continue past OpenCode sessions via the SQLite DB or CLI
- **[questions.md](questions.md)** — answer a pending `question` tool call in another session via the API
- **[repair.md](repair.md)** — fix blank sessions, missing worktrees, duplicate project rows, and DB issues
- **[reset-diff.md](reset-diff.md)** — fix stale or noisy "Modified Files" sidebar after a commit, rebase, or merge
