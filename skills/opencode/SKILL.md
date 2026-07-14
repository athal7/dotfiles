---
name: opencode
description: OpenCode agent runtime — manage sessions, dispatch tasks, repair DB issues, and reset diffs
license: MIT
compatibility: opencode
---

Unified skill for all OpenCode agent runtime operations. Use the reference files below for each area.

## Dispatch & coordination

`aoe` (Agent of Empires) is the only interface for creating and interacting with OpenCode sessions — there is no daemon and no HTTP API. Every session is a real opencode TUI running inside a tmux pane that aoe manages. **Run `aoe --help` and `aoe <subcommand> --help` for the full flag reference** — don't restate syntax here; flags change between releases.

- **Create a session**: `aoe add <path> --tool opencode --title <title>` creates the session record, then `aoe session start <id>` actually starts the tmux pane running opencode. These are two separate calls — `aoe add ... --launch` tries to interactively attach right after creating, which fails in a non-TTY context (scripts, LaunchAgents).
- **Worktrees are mandatory for branch/parallel work**: any task reviewing/modifying a branch, or parallel work on the same repo, must run in a worktree — concurrent sessions in one directory clobber each other's checkouts, stashes, and index. Pass `--worktree <branch> --new-branch` to `aoe add` to create the session directly in a fresh worktree on a new branch (`--base-branch <branch>` to base it on something other than the repo default).
- **`<path>` is only ever canonicalized, never resolved to the main repo.** `aoe add <path>` symlink-resolves whatever you pass and silently treats that exact path as (or creates) the project root — it never walks a worktree back to its repo's main checkout, so pointing it at a worktree spins up a bogus project with no warning. Always pass the project's exact registered path (check `aoe project list`) plus `--worktree <branch>` (`--new-branch`/`--base-branch` as needed) to attach a fresh worktree to the right project. `--project <name>`/`--repo <path>` don't help here — they only add extra repos to a multi-repo workspace alongside `--worktree` and error loudly on an unregistered name; they're not a way to specify the primary target by name.
- **Send a message**: `aoe send <id> "<message>"` types the message into the session's tmux pane and submits it. It's fire-and-forget — there's no blocking "wait for the reply" verb; the session keeps running after `send` returns, and you check back later via `aoe session capture <id>` or by attaching.
- **opencode's TUI takes a few seconds to boot** in a freshly-started tmux pane. A `send` issued immediately after `aoe session start` can be silently dropped (no error, `send` still reports success) — sleep ~5s after `session start` before the first `send`.
- **Slash commands need a trailing space**: opencode's TUI treats a leading `/` as the start of its slash-command autocomplete dropdown, and `aoe send`'s trailing Enter gets consumed by the dropdown instead of submitting. A trailing space closes the dropdown as it's typed so the following Enter submits normally (e.g. `aoe send <id> "/audit "`).
- **Interact directly**: `aoe session attach <id>` attaches interactively to the session's tmux pane — use this for anything beyond a single fire-and-forget message (a back-and-forth, for example).
- **Inspect without attaching**: `aoe session capture <id>` dumps the current tmux pane content — useful for checking on a dispatched session's progress or confirming a message landed.
- **One task per session** — don't queue prompts into a busy session; check `aoe list` for what's already running before starting overlapping work in the same directory.
- **Dispatch the intent, not the decomposition** — send e.g. `Workflow: implement. Linear issue KEY-1234`, not the individual steps; the receiving session has its own AGENTS.md/skills/plan agent to drive.

## Read-only history

For anything that doesn't need a live session — looking up a past conversation, exporting it, or resuming it — use the plain `opencode` CLI or direct SQLite reads, never a daemon:

- `opencode session list` — list sessions
- `opencode export <sessionID>` — export a session's full message/part history as JSON
- `opencode -c` / `opencode -s <sessionID>` — resume the last (or a specific) session's conversation in a fresh interactive TUI
- Direct reads against `~/.local/share/opencode/opencode.db` (SQLite, WAL mode — safe to read while a session is live)

See [sessions.md](sessions.md) for the full query cookbook.

## Reference files

- **[sessions.md](sessions.md)** — list, search, read, and continue past OpenCode sessions via the SQLite DB or CLI
- **[repair.md](repair.md)** — fix blank sessions, missing worktrees, duplicate project rows, and DB issues
- **[reset-diff.md](reset-diff.md)** — fix stale or noisy "Modified Files" sidebar after a commit, rebase, or merge
