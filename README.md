# athal7's dotfiles

macOS development environment managed with [chezmoi](https://chezmoi.io).

## Overview

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: OMP uses `~/.config/omp/` as its global root through `PI_CONFIG_DIR=.config/omp`, with agent data under `~/.config/omp/agent/` through `PI_CODING_AGENT_DIR` in shells, AoE sessions, and LaunchAgents. MCP servers are defined in [.chezmoidata/mcp.yaml](.chezmoidata/mcp.yaml). Shared [agent skills](dot_agents/skills/) deploy to `~/.agents/skills/`; OMP hooks default omitted Eval deadlines to unlimited. The [pre-tool verb hook](dot_config/omp/private_agent/hooks/pre/verb-permissions.ts) requests approval for mutating Bash commands and MCP calls. Bash matching inspects executable and subcommand positions, not argument text; it is a heuristic, not a shell sandbox (terminal keystrokes sent across separate calls are not tracked).
  The registry `name` is the OMP server selector label: connectors use names such as `slack` and `atlassian`, while Runlayer's own server is `runlayer`. Endpoint variables retain their `RUNLAYER_*_MCP_URL` names.
  Browser access asks once per OMP session through an [agent instruction](dot_config/omp/private_agent/APPEND_SYSTEM.md); later browser calls are allowed without tool prompts. First-use consent is instruction-based, not enforced by OMP tool approval.
  Code review findings have no priority or severity labels; only nits carry `nit:`.
  AoE loads the optional Anthropic API key from Keychain when launching host OMP sessions; restart running sessions to pick up a newly added or rotated key.
  AoE stores global config, profiles, plugins, and runtime state under `~/.config/agent-of-empires/`; its chezmoi-managed `config.toml` and plugin installer target that directory. The tmux status line is intentionally minimal; use `C-b s`/`C-b w` for session/window selection. When migrating an existing machine, copy the complete `~/.agent-of-empires/` tree into the XDG directory before applying chezmoi: AoE keeps using legacy if XDG is absent, but immediately switches to XDG when that directory exists. Verify the migrated config and sessions with `aoe settings explain session.default_tool` and `aoe list` before considering removal of legacy data.
  AoE Serve binds to loopback behind private Tailscale Serve and uses the Keychain passphrase with `--auth passphrase`; its dashboard needs no URL token.
- Local AI: [model provider](dot_config/omp/private_agent/models.yml.tmpl) and [llama.cpp service](dot_config/launchd-yaml/agents.yaml.tmpl).
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl), including weekly removal of Google Chrome signing clones older than 24 hours only when Chrome is stopped and the tree has no open files, plus weekly cleanup of idle merged worktrees, 30-day-old ignored Rust build artifacts in clean idle worktrees, and disconnected development/test databases; [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](https://github.com/athal7/cal), and [Homebridge](dot_config/homebridge/).
  Homebridge uses `~/.config/homebridge` as its `-U` storage directory. Before deploying the path change, stop its LaunchAgent; require `~/.homebridge/config.json` to exist and parse. Preserve any existing `~/.config/homebridge` by renaming it to a unique backup, then move the entire legacy directory and verify the moved JSON before restarting.
  For GitHub session actions, attention uses the local checkout under `codeDir` or a registered AoE project whose GitHub origin matches the item. Register checkouts outside `codeDir` with AoE first.
- Packages: [package registry](.chezmoidata/packages.yaml) and [external downloads](.chezmoiexternal.toml.tmpl). The registry installs `cal-automation` from its tagged repository through mise’s `pipx:` backend before the calendar LaunchAgents reload. [Its private XDG config](dot_config/cal/private_config.json.tmpl) is rendered at `~/.config/cal/config.json` from gitignored `.chezmoidata/local.yaml`; no calendar settings are committed.
- Local containers: Homebrew Docker CLI and Compose use [Colima](https://github.com/abiosoft/colima) with the Docker runtime. Its LaunchAgent starts the default VM with 4 GiB of memory and a 30 GiB disk limit; shells set DOCKER_HOST to $HOME/.colima/default/docker.sock, replacing stale inherited values. Set DOCKER_HOST after shell startup to use another daemon. Compose discovers the Homebrew plugin through ~/.docker/cli-plugins/docker-compose without replacing ~/.docker/config.json. Containers mounting /var/run/docker.sock can control sibling containers through the VM's Docker daemon; treat that mount as privileged. Apple Container remains installed for its own CLI and other consumers; Colima does not migrate or delete its data.
- KB collectors: [definitions](dot_config/kb/collectors/) deploy to `~/.config/kb/collectors/`; each Markdown file's front-matter `name` is its canonical registry identity.

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Copy [`local.yaml.example`](local.yaml.example) to `.chezmoidata/local.yaml` for machine-specific data.

For higher Context7 MCP quotas, create a free API key at [Context7](https://context7.com/dashboard) and store it in macOS Keychain:

```bash
security add-generic-password -U -s context7 -a api-key -w
```

The final `-w` prompts for the key rather than putting it in shell history. Without a Keychain item under service `context7`, Context7 stays available anonymously.
Chezmoi renders the key into private `~/.config/omp/agent/mcp.json`; after adding or rotating it, run `chezmoi apply` and `/mcp reload` in OMP.

The `codebase-memory` MCP server builds a local persistent code index for reuse across OMP sessions using the same project checkout. Its index lives under `~/.cache/codebase-memory-mcp`; new-project auto-indexing is off by default, so run its `index_repository` tool once per project. Separate worktrees are separate indexes; the index is a search aid, not a substitute for reading current source.
