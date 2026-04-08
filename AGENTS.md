# Chezmoi Dotfiles Repository

This repo manages `~` via chezmoi. Edit source files here, run `chezmoi apply` to deploy.

## Structure

- **`dot_*`** — home directory files and directories (shell, git, editors, app configs)
- **`dot_config/opencode/`** — OpenCode config: model, MCPs, plugins, permissions, agent instructions
- **`dot_agents/skills/`** — agent skills deployed to `~/.agents/skills/`
- **`Library/LaunchAgents/`** — macOS services (opencode web on port 4096)
- **`.chezmoidata/packages.yaml`** — single package registry: brew, cask, mise, github releases
- **`.chezmoiexternal.toml.tmpl`** — generated from packages.yaml, drives chezmoi-native GitHub release downloads
- **`.chezmoiscripts/`** — run on apply: brew bundle, launchagent reload, opencode restart

## Packages

All packages are declared in `.chezmoidata/packages.yaml` under `brews`, `casks`, `mise`, or `github_releases`. The install scripts and external file are generated from it — edit only the registry.

## OpenCode Config

`opencode.json` is validated against its schema before the web service restarts. If apply succeeds but the server doesn't come back, check the error log and fix the JSON before re-applying.

MCPs, plugins, and permissions are all in `opencode.json`. Skills live in `dot_agents/skills/` — edit here, not in `~/.agents/skills/`.

## Host-Specific Files (NOT managed by chezmoi)

- `~/.env` — API keys and secrets (loaded by direnv)
