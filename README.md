# athal7's dotfiles

macOS development environment managed with [chezmoi](https://chezmoi.io).

## Overview

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: OMP's complete config is managed under [dot_config/omp/](dot_config/omp/), deployed to ~/.config/omp/agent/; shells set PI_CONFIG_DIR=.config/omp. MCP servers are defined in [.chezmoidata/mcp.yaml](.chezmoidata/mcp.yaml). Shared [agent skills](dot_agents/skills/) and the [agent-perms policy](dot_agents/permissions.json) deploy under ~/.agents/; OMP discovers skills natively from ~/.agents/skills/.
  Browser access asks once per OMP session through an [agent instruction](dot_config/omp/private_agent/APPEND_SYSTEM.md); later browser calls are allowed without tool prompts. First-use consent is instruction-based, not enforced by OMP's tool approval policy.
  OMP discovers the shared skills; its ordered Bash approvals remain native because agent-perms' deny/ask-first evaluation cannot represent their matching precedence.
  AoE loads the optional Anthropic API key from Keychain when launching host OMP sessions; restart running sessions to pick up a newly added or rotated key.
  AoE Serve binds to loopback behind private Tailscale Serve and uses the Keychain passphrase with `--auth passphrase`; its dashboard needs no URL token.
- Local AI: [model provider](dot_config/omp/private_agent/models.yml.tmpl) and [llama.cpp service](dot_config/launchd-yaml/agents.yaml.tmpl).
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl), including weekly cleanup of idle merged worktrees and disconnected development/test databases; [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](dot_local/lib/cal/), and [Homebridge](dot_config/homebridge/).
  Homebridge uses `~/.config/homebridge` as its `-U` storage directory. Before deploying this path change, stop Homebridge and move the complete existing `~/.homebridge` directory to `~/.config/homebridge` to retain its credentials and accessory state.
  For GitHub session actions, attention uses the local checkout under `codeDir` or a registered AoE project whose GitHub origin matches the item. Register checkouts outside `codeDir` with AoE first.
- Packages: [package registry](.chezmoidata/packages.yaml) and [external downloads](.chezmoiexternal.toml.tmpl).
- KB collectors: [definitions](dot_config/kb/collectors/) deploy to `~/.config/kb/collectors/`; each Markdown file's front-matter `name` is its canonical registry identity.

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Copy [`local.yaml.example`](local.yaml.example) to `.chezmoidata/local.yaml` for machine-specific data.

Before deploying the OMP XDG path change, close OMP and move its full `~/.omp` directory to `~/.config/omp`; this preserves its credentials, sessions, and installed agent data. The shell environment then points OMP at the new config root. This is a one-time manual migration; chezmoi does not remove the old target when a source path is removed.

For higher Context7 MCP quotas, create a free API key at [Context7](https://context7.com/dashboard) and store it in macOS Keychain:

```bash
security add-generic-password -U -s context7 -a api-key -w
```

The final `-w` prompts for the key rather than putting it in shell history. Without a Keychain item under service `context7`, Context7 stays available anonymously.
Chezmoi renders the key into private `~/.config/omp/agent/mcp.json`; after adding or rotating it, run `chezmoi apply` and `/mcp reload` in OMP.

The `codebase-memory` MCP server builds a local persistent code index for reuse across OMP sessions using the same project checkout. Its index lives under `~/.cache/codebase-memory-mcp`; new-project auto-indexing is off by default, so run its `index_repository` tool once per project. Separate worktrees are separate indexes; the index is a search aid, not a substitute for reading current source.
