---
name: chezmoi
description: Manage dotfiles via chezmoi — apply safely, destroy files, manage LaunchAgents and externals, config and template gotchas
license: MIT
compatibility: opencode
---

`chezmoi apply` deploys source files to `~` and runs `run_onchange` scripts (brew bundle, skill sync, etc.).

## Deploy workflow

Changes land via `chezmoi-deploy`, not pull requests. The source dir is pinned to the primary checkout, so a bare `chezmoi apply` always reads `main` — work is verified render-only until deployed.

- **Verify render-only — never a bare `chezmoi apply` from a worktree.** Pass `-S "$(pwd)"` with no-mutation verbs: `chezmoi diff -S "$(pwd)"`, `chezmoi apply -n -v -S "$(pwd)"` (dry-run; also shows which scripts would fire), `chezmoi cat -S "$(pwd)" <target>`.
- **Deploy with `chezmoi-deploy <branch>`.** It locks, fast-forward-merges the branch into the primary checkout's `main`, runs `chezmoi apply --force`, and pushes `main` to origin. Safe from a hosted aoe session: the session runs in a tmux pane independent of any LaunchAgent, and the generator only reloads agents whose plist content actually changed — it never touches the tmux pane a deploy is running from. Gated by an `ask` permission.
- **Escape hatch** — to exercise one deployed file's runtime behavior without a full deploy: `chezmoi apply -S "$(pwd)" --exclude=scripts --persistent-state "${TMPDIR:-/tmp}/branch-state.boltdb" <target>` — mutates only that path, runs no scripts, leaves global state untouched.

`chezmoi apply` reloads changed LaunchAgents automatically — the `run_onchange_after_aa-launch-agents.sh` generator renders plists from `dot_config/launchd-yaml/agents.yaml` and reloads only what changed. To force-reload an agent manually during testing:

```sh
# Restart a running agent (picks up plist changes):
launchctl kickstart -k "gui/$(id -u)/<label>"

# Full reload (for structural changes like new binary paths):
launchctl bootout "gui/$(id -u)/<label>"
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/<plist-file>

# Load a new agent for the first time:
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/<plist-file>
```

## Notes

- Session transcript data is persisted in `~/.local/share/opencode/opencode.db` — sessions survive restarts
- **Adding a new `[data]` key to `.chezmoi.toml.tmpl` requires `chezmoi init` before `chezmoi apply`** — `apply` alone does not regenerate `~/.config/chezmoi/chezmoi.toml`
- **`chezmoi init` is destructive to the live config** — it re-renders the template from scratch. The "config file template has changed" warning from `chezmoi apply` is cosmetic when scripts are already deployed; do not run `chezmoi init` to silence it.
- **Machine-specific config lives in `.chezmoidata/local.yaml`** in the source directory — secrets manifest, calendar config, reminders, per-org config. This file is gitignored. Copy `local.yaml.example` from the repo root to `~/.local/share/chezmoi/.chezmoidata/local.yaml` to get started. The example must NOT live under `.chezmoidata/` itself — files there get merged into `chezmoi data` and would leak placeholder values into runtime.

## Gotchas

- **`.chezmoidata` values are plain data** — template expressions like `{{ .chezmoi.arch }}` inside YAML string values are not evaluated. Arch/OS logic must live in the `.tmpl` file itself.
- **`.app` bundles via `chezmoiexternal`** — use `type = "archive"` with target `"Applications/<AppName>.app"` (unique TOML key per app) and `stripComponents = 1` to strip the archive's root directory. Without `stripComponents = 1` the app ends up double-nested inside the archive's root directory. TOML does not allow duplicate keys, so each app needs its own unique target path.
- **LaunchAgent binary path changes** — after moving a binary (e.g., brew → `~/.local/bin`), `launchctl bootout` + `bootstrap` is required to pick up the new plist; `kickstart` alone is not sufficient if the service is crash-looping.
- **Updating a plist** — apply first to deploy the new file, then `launchctl kickstart -k gui/$(id -u)/<label>` to reload.
- **Inline shell in plist templates** — avoid `/bin/sh -c` with inline scripts in `ProgramArguments`. Three escaping layers (XML entities, shell quoting, content characters) make this fragile — an apostrophe in text content will silently break single-quoted strings, `&` needs `&amp;` in XML, etc. Use `ProgramArguments` with a standalone script instead: each argument is a separate `<string>` element, no shell involved.
- **Deleting a managed file** — `chezmoi apply` does not remove files whose source entry was deleted. Use `chezmoi destroy <target>` *before* removing the source entry — it removes both in one step. **Order matters:** if you `git rm` the source first, `chezmoi destroy` returns `not managed` and you must `rm` the deployed file manually. Note: files managed via `.chezmoiexternal.toml.tmpl` cannot be destroyed this way — chezmoi owns them; remove the external entry instead.
- **Deleting a skill** — skills in `skills/` are synced to `~/.agents/skills/` by the `run_onchange_after_sync-and-validate-skills` script, which replaces local skills wholesale. Removing a skill from `skills/` is sufficient — no `chezmoi destroy` needed. External skills (in `packages.skills`) must be removed from the list; they will be gone on the next apply.
- **Empty files are skipped** — chezmoi does not deploy 0-byte files. Python `__init__.py` files need at least a comment (e.g., `# package name`) or they won't appear at the target.
- **"X has changed since chezmoi last wrote it" prompt** — chezmoi's persistent state SHA for that target drifted from the live file (often after an external tool rewrote it, after a template edit between sessions, or after picking `s`kip in a previous prompt). If `chezmoi diff` is empty after the prompt, the live and rendered content actually match — pick `o`verwrite (or rerun with `--force`) to resync state. Picking `s`kip leaves state stale and the prompt will reappear next apply. Recurring offender: `~/.zshrc`, occasionally rewritten by tool installers (bun, mise) at session startup.
- **`__pycache__` under managed lib dirs** — Python bytecache in `~/.local/lib/{kb,cal}/__pycache__/` is generated at runtime and triggers "has changed since chezmoi last wrote it" prompts on every apply. Fix: add `**/__pycache__` to `.chezmoiignore`.
- **Non-TTY "has changed" prompt fails** — when `chezmoi apply` runs from an agent session (no TTY attached), the interactive prompt errors with "could not open a new TTY: open /dev/tty: device not configured". Use `chezmoi apply --force` to skip prompts in non-interactive contexts.
- **`chezmoi-templates` pre-commit hook renders against the current worktree, not the primary checkout** — it passes `-S "$(git rev-parse --show-toplevel)"`, so it now correctly catches templates referencing a `.chezmoidata/*.yaml` key that only exists on the current branch (previously it silently validated against the primary checkout's `main` data and always passed). The tradeoff: `.chezmoidata/local.yaml` is gitignored, so worktrees never receive it — templates depending on it will fail this hook when committed from *any* worktree. Known affected templates: `dot_envrc.tmpl` (needs `.secrets`) and `dot_config/opencode/opencode.json.tmpl` (needs `.runlayer`). Workaround: symlink `.chezmoidata/local.yaml` from the primary checkout into the worktree before committing, or bypass the hook for that one commit.
