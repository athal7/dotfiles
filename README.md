# athal7's dotfiles

macOS development environment managed with [chezmoi](https://chezmoi.io).

## Overview

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: OMP config is staged under `~/.config/omp/agent/`, while active OMP continues using `~/.omp/agent/` until the quiescent state-copy and symlink cutover. MCP servers are defined in [.chezmoidata/mcp.yaml](.chezmoidata/mcp.yaml). Shared [agent skills](dot_agents/skills/) deploy to `~/.agents/skills/`; the OMP pre-tool hook applies one verb policy to Bash and MCP calls.
  Browser access asks once per OMP session through an [agent instruction](dot_config/omp/private_agent/APPEND_SYSTEM.md); later browser calls are allowed without tool prompts. First-use consent is instruction-based, not enforced by OMP tool approval.
  AoE loads the optional Anthropic API key from Keychain when launching host OMP sessions; restart running sessions to pick up a newly added or rotated key.
  AoE Serve binds to loopback behind private Tailscale Serve and uses the Keychain passphrase with `--auth passphrase`; its dashboard needs no URL token.
- Local AI: [model provider](dot_config/omp/private_agent/models.yml.tmpl) and [llama.cpp service](dot_config/launchd-yaml/agents.yaml.tmpl).
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl), including weekly cleanup of idle merged worktrees and disconnected development/test databases; [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](dot_local/lib/cal/), and [Homebridge](dot_config/homebridge/).
  Homebridge uses `~/.config/homebridge` as its `-U` storage directory. Before deploying the path change, stop its LaunchAgent; require `~/.homebridge/config.json` to exist and parse. Preserve any existing `~/.config/homebridge` by renaming it to a unique backup, then move the entire legacy directory and verify the moved JSON before restarting.
  For GitHub session actions, attention uses the local checkout under `codeDir` or a registered AoE project whose GitHub origin matches the item. Register checkouts outside `codeDir` with AoE first.
- Packages: [package registry](.chezmoidata/packages.yaml) and [external downloads](.chezmoiexternal.toml.tmpl).
- KB collectors: [definitions](dot_config/kb/collectors/) deploy to `~/.config/kb/collectors/`; each Markdown file's front-matter `name` is its canonical registry identity.

## OMP XDG Cutover

The staged configuration lives physically under `~/.config/omp/agent`; OMP continues to use and report the logical path `~/.omp/agent`. Do not set `PI_CONFIG_DIR`. After cutover, `~/.omp -> .config/omp` makes the logical path resolve to the physical XDG tree.

Cut over after this OMP session and every other OMP/AoE writer has exited. Boot out `com.$USER.aoe-serve` and `com.$USER.aoe-daily-maintenance` if loaded; verify no OMP/AoE process remains and `lsof +D "$HOME/.omp"` finds no writer.
Use one timestamp to preserve any existing `$XDG_DATA_HOME/omp`, `$XDG_STATE_HOME/omp`, `$XDG_CACHE_HOME/omp`, and `~/.config/omp` as separate backups. Never merge SQLite databases.
Copy the complete `~/.omp` tree to `~/.config/omp`, excluding the five managed agent files listed below. Verify the copy with `rsync -anEc --itemize-changes` using identical exclusions and run SQLite `PRAGMA quick_check` on copied databases.
After checks, deploy the `symlink_dot_omp` source with `chezmoi-deploy <branch>`; never run `chezmoi apply` from a worktree.
Verify `readlink ~/.omp` is `.config/omp`, `realpath ~/.omp` resolves to `~/.config/omp`, `omp config path` still reports the logical `~/.omp/agent`, and a known old session loads.

The copy excludes the five managed agent files (`config.yml`, `mcp.json`, `models.yml`, `kb-enrich-mcp.json`, `APPEND_SYSTEM.md`); chezmoi recreates them from source after the symlink is applied.

Rollback is also post-session: stop all writers, preserve the current XDG tree and category roots as fresh backups, restore the timestamped legacy `~/.omp` backup and separate pre-cutover XDG category and experimental-config backups. Never merge SQLite databases.

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Copy [`local.yaml.example`](local.yaml.example) to `.chezmoidata/local.yaml` for machine-specific data.

OMP state and symlink cutover are separate post-session steps; follow [OMP XDG Cutover](#omp-xdg-cutover). Never apply the symlink while any OMP/AoE writer is active.

See [OMP XDG Cutover](#omp-xdg-cutover) for copy exclusions, integrity checks, activation, and rollback.

For higher Context7 MCP quotas, create a free API key at [Context7](https://context7.com/dashboard) and store it in macOS Keychain:

```bash
security add-generic-password -U -s context7 -a api-key -w
```

The final `-w` prompts for the key rather than putting it in shell history. Without a Keychain item under service `context7`, Context7 stays available anonymously.
Chezmoi renders the key into private `~/.config/omp/agent/mcp.json`; after adding or rotating it, run `chezmoi apply` and `/mcp reload` in OMP.

The `codebase-memory` MCP server builds a local persistent code index for reuse across OMP sessions using the same project checkout. Its index lives under `~/.cache/codebase-memory-mcp`; new-project auto-indexing is off by default, so run its `index_repository` tool once per project. Separate worktrees are separate indexes; the index is a search aid, not a substitute for reading current source.
