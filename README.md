# athal7's dotfiles

macOS development environment managed with [chezmoi](https://chezmoi.io).

## Overview

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: OMP uses `~/.config/omp/agent/` directly through `PI_CODING_AGENT_DIR` in shells, AoE sessions, and LaunchAgents. MCP servers are defined in [.chezmoidata/mcp.yaml](.chezmoidata/mcp.yaml). Shared [agent skills](dot_agents/skills/) deploy to `~/.agents/skills/`; the OMP pre-tool hook applies one verb policy to Bash and MCP calls.
  Browser access asks once per OMP session through an [agent instruction](dot_config/omp/private_agent/APPEND_SYSTEM.md); later browser calls are allowed without tool prompts. First-use consent is instruction-based, not enforced by OMP tool approval.
  AoE loads the optional Anthropic API key from Keychain when launching host OMP sessions; restart running sessions to pick up a newly added or rotated key.
  AoE Serve binds to loopback behind private Tailscale Serve and uses the Keychain passphrase with `--auth passphrase`; its dashboard needs no URL token.
- Local AI: [model provider](dot_config/omp/private_agent/models.yml.tmpl) and [llama.cpp service](dot_config/launchd-yaml/agents.yaml.tmpl).
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl), including weekly cleanup of idle merged worktrees and disconnected development/test databases; [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](dot_local/lib/cal/), and [Homebridge](dot_config/homebridge/).
  Homebridge uses `~/.config/homebridge` as its `-U` storage directory. Before deploying the path change, stop its LaunchAgent; require `~/.homebridge/config.json` to exist and parse. Preserve any existing `~/.config/homebridge` by renaming it to a unique backup, then move the entire legacy directory and verify the moved JSON before restarting.
  For GitHub session actions, attention uses the local checkout under `codeDir` or a registered AoE project whose GitHub origin matches the item. Register checkouts outside `codeDir` with AoE first.
- Packages: [package registry](.chezmoidata/packages.yaml) and [external downloads](.chezmoiexternal.toml.tmpl).
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
