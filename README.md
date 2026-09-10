# athal7's dotfiles

macOS development environment managed with [chezmoi](https://chezmoi.io).

## Overview

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: [OMP](dot_omp/private_agent/), [MCP servers](.chezmoidata/mcp.yaml), [agent skills](dot_agents/skills/), and [Agent of Empires](dot_agent-of-empires/modify_config.toml).
- Local AI: [model provider](dot_omp/private_agent/models.yml.tmpl) and [llama.cpp service](dot_config/launchd-yaml/agents.yaml.tmpl).
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl), [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](dot_local/lib/cal/), and [Homebridge](dot_homebridge/).
- Packages: [package registry](.chezmoidata/packages.yaml) and [external downloads](.chezmoiexternal.toml.tmpl).

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Copy [`local.yaml.example`](local.yaml.example) to `.chezmoidata/local.yaml` for machine-specific data.
