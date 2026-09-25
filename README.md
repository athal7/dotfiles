# athal7's dotfiles

macOS development environment managed with [chezmoi](https://chezmoi.io).

## Overview

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: the complete [OMP config](dot_omp/private_agent/private_config.yml) is directly managed; [MCP servers](.chezmoidata/mcp.yaml), [agent skills](dot_agents/skills/), and [Agent of Empires](dot_agent-of-empires/modify_config.toml).
  Browser access asks once per OMP session through an [agent instruction](dot_omp/private_agent/APPEND_SYSTEM.md); later browser calls are allowed without tool prompts. First-use consent is instruction-based, not enforced by OMP's tool approval policy.
  AoE loads the optional Anthropic API key from Keychain when launching host OMP sessions; restart running sessions to pick up a newly added or rotated key.
- Local AI: [model provider](dot_omp/private_agent/models.yml.tmpl) and [llama.cpp service](dot_config/launchd-yaml/agents.yaml.tmpl).
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl), including weekly cleanup of idle merged worktrees and disconnected development/test databases; [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](dot_local/lib/cal/), and [Homebridge](dot_homebridge/).
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
Chezmoi renders the key into private `~/.omp/agent/mcp.json`; after adding or rotating it, run `chezmoi apply` and `/mcp reload` in OMP.
