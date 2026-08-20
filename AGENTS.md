# Chezmoi Dotfiles Repository

This repo manages `~` via chezmoi. Edit source files here, run `chezmoi apply` to deploy.

**No pull requests — deploy is the ship step.** Land changes with `chezmoi-deploy <branch>`: it fast-forward-merges the branch into the primary checkout's `main`, runs `chezmoi apply`, and pushes `main` to origin as a mirror. Only `chezmoi apply` mutates your live `~`. Load the chezmoi skill for verify-render-only and deploy mechanics.

**`chezmoi apply` auto-deploys and reloads changed LaunchAgents.** The `run_onchange_after_aa-launch-agents.sh` generator renders every plist from `dot_config/launchd-yaml/agents.yaml.tmpl` (yq → plutil), then reloads only agents whose plist content actually changed and prunes agents deleted from the YAML — so unchanged agents are never restarted. The individual plists are NOT chezmoi-managed; the generator owns them. To force-run a scheduled job for testing, you can still kickstart it manually: `launchctl kickstart -k gui/$(id -u)/<label>`.

## Structure

- **`dot_*`** — home directory files and directories (shell, git, editors, app configs)
- **`dot_omp/private_agent/`** — OMP's sole config writers: `config.yml.tmpl`, `private_mcp.json.tmpl`, and the lead-prompt symlink.
- **`.chezmoidata/mcp.yaml`** — neutral MCP server data rendered into OMP templates.
- **`dot_agents/skills/`** — authored agent skills managed natively at `~/.agents/skills/`; externally installed skills own separate sibling directories.
- **`dot_config/launchd-yaml/agents.yaml.tmpl`** — macOS services (scheduled jobs and daemons) defined declaratively; deployed, reloaded, and pruned by the `.chezmoiscripts/run_onchange_after_aa-launch-agents.sh` generator (renders via yq → plutil, reloads only changed agents, removes agents deleted from the YAML). Individual plists are not chezmoi-managed.
- **`.chezmoidata/packages.yaml`** — single package registry: brew, cask, mise, github releases
- **`.chezmoidata/local.yaml`** — private machine and organization data, including model defaults and per-org overrides; gitignored and represented publicly only by `local.yaml.example`.
- **`.chezmoiexternal.toml.tmpl`** — generated from packages.yaml, drives chezmoi-native GitHub release downloads
- **`.chezmoiscripts/`** — run on apply only where generation or an external installer is required

## Packages

All packages are declared in `.chezmoidata/packages.yaml` under `brews`, `casks`, `mise`, `github_releases`, or `aoe_plugins` (aoe/Agent of Empires plugins, installed/updated via `run_onchange_after_plugins-aoe.sh.tmpl`). The install scripts and external file are generated from it — edit only the registry.

## Agent Config

`dot_omp/private_agent/config.yml.tmpl` owns OMP's complete native target; `dot_omp/private_agent/APPEND_SYSTEM.md` owns its system prompt.

## Public Repo — Privacy Guidelines

This is a **public repository**. Before committing any content, check for:

- **Work-specific content** — employer names, internal project names, org names, team names, internal URLs, internal hostnames, internal tool names. Replace with generic equivalents (e.g. `myapp`, `myorg`, `your-work-email`).
- **Secrets** — API keys, tokens, passwords, credentials. These must never appear in committed files. Use `promptStringOnce` in `.chezmoi.toml.tmpl` and `modify_private_dot_env.tmpl` for anything sensitive.
- **Personal identifiers** — email addresses, Slack user IDs, Linear team IDs, phone numbers. These belong in chezmoi data, not in committed files.
- **Infrastructure details** — internal hostnames, IP ranges, VPN configs, cluster names, cloud project IDs. Keep these in `~/.config/zsh/private.zsh` (not tracked).

When writing skills, examples, or documentation: use generic placeholder names (`myapp`, `myorg`, `your-repo`) rather than real project or employer names.

## README

Keep `README.md` up to date when making structural changes: adding or removing skills, new LaunchAgents, new config sections, changes to the package registry design, or anything that affects how someone would use or contribute to this repo. The README is the primary entry point for external readers.
