# Chezmoi Dotfiles Repository

This repo manages `~` via chezmoi. Edit source files here, run `chezmoi apply` to deploy.

**No pull requests — deploy is the ship step.** Land changes with `chezmoi-deploy <branch>`: it fast-forward-merges the branch into the primary checkout's `main`, runs `chezmoi apply`, and pushes `main` to origin as a mirror. Only `chezmoi apply` mutates your live `~`. Load the chezmoi skill for verify-render-only and deploy mechanics.

**`chezmoi apply` auto-deploys and reloads changed LaunchAgents.** The `run_onchange_after_aa-launch-agents.sh` generator renders every plist from `dot_config/launchd-yaml/agents.yaml.tmpl` (yq → plutil), then reloads only agents whose plist content actually changed and prunes agents deleted from the YAML — so unchanged agents are never restarted. The individual plists are NOT chezmoi-managed; the generator owns them. To force-run a scheduled job for testing, you can still kickstart it manually: `launchctl kickstart -k gui/$(id -u)/<label>`.

## Structure

- **`dot_*`** — home directory files and directories (shell, git, editors, app configs)
- **`dot_config/opencode/`** — OpenCode-specific files that aren't agent config: plugin settings (`dcp.jsonc`), slash commands (`commands/`). `opencode.json` itself is agentcfg-owned (see below), not templated here.
- **`dot_config/agentcfg/`** — the single registry driving both opencode's and omp's agent/workflow config via [`agentcfg`](https://github.com/athal7/agentcfg), applied by `.chezmoiscripts/run_onchange_after_agentcfg-apply.sh.tmpl`. `workflow.yaml.tmpl` declares every agent/step once (prompt, permissions, role, MCP grants); `mcp_servers.yaml` declares every MCP server once; `agentcfg.yaml.tmpl`'s `harnesses.<id>.extra` covers config neither renderer's registry model has a field for (opencode.json's static server/plugin/provider/formatter/lsp blocks; omp's `tools.approvalMode`/`task.disabledAgents`/`compaction.strategy`). Adding a "reach service X via MCP" subagent is a `workflow.yaml.tmpl` step plus an `mcp_servers.yaml` entry — no separate per-agent prompt file needed unless the prompt itself is long enough to warrant `prompt.file` over inline `prompt.text`.
- **`skills/`** — agent skills deployed to `~/.agents/skills/`. Multi-step commands (`dot_config/agentcfg/commands.yaml.tmpl`, if present) render additional skills into the same directory — see `docs.schema.md`'s `commands:` section in the agentcfg repo.
- **`dot_config/launchd-yaml/agents.yaml.tmpl`** — macOS services (scheduled jobs and daemons) defined declaratively; deployed, reloaded, and pruned by the `.chezmoiscripts/run_onchange_after_aa-launch-agents.sh` generator (renders via yq → plutil, reloads only changed agents, removes agents deleted from the YAML). Individual plists are not chezmoi-managed.
- **`.chezmoidata/packages.yaml`** — single package registry: brew, cask, mise, github releases
- **`.chezmoidata/agents.yaml`** — per-org model-class overrides only (`dot_local/bin/executable_aoe-model-class` reads it from `chezmoi data` at aoe launch time); NOT an agent-definition source anymore — that's `dot_config/agentcfg/workflow.yaml.tmpl`.
- **`.chezmoiexternal.toml.tmpl`** — generated from packages.yaml, drives chezmoi-native GitHub release downloads
- **`.chezmoiscripts/`** — run on apply: brew bundle, skill sync, agentcfg apply

## Packages

All packages are declared in `.chezmoidata/packages.yaml` under `brews`, `casks`, `mise`, `github_releases`, or `aoe_plugins` (aoe/Agent of Empires plugins, installed/updated via `run_onchange_after_plugins-aoe.sh.tmpl`). The install scripts and external file are generated from it — edit only the registry.

## OpenCode Config

MCPs, plugins, agent definitions, and permissions all end up in `opencode.json`, but it's agentcfg-owned — edit `dot_config/agentcfg/` (agent/MCP/permission content) or `agentcfg.yaml.tmpl`'s `harnesses.opencode.extra` (everything else: server, plugin, provider, formatter, lsp), never `opencode.json` directly; the next `agentcfg apply` overwrites it. Skills live in `skills/` — edit here, not in `~/.agents/skills/`.

**Keep the global `dot_config/opencode/AGENTS.md` lean.**  Resist adding DO/DO NOT lists to it. Long instruction files degrade agent performance — prefer skills and progressive context loading instead.

## Public Repo — Privacy Guidelines

This is a **public repository**. Before committing any content, check for:

- **Work-specific content** — employer names, internal project names, org names, team names, internal URLs, internal hostnames, internal tool names. Replace with generic equivalents (e.g. `myapp`, `myorg`, `your-work-email`).
- **Secrets** — API keys, tokens, passwords, credentials. These must never appear in committed files. Use `promptStringOnce` in `.chezmoi.toml.tmpl` and `modify_private_dot_env.tmpl` for anything sensitive.
- **Personal identifiers** — email addresses, Slack user IDs, Linear team IDs, phone numbers. These belong in chezmoi data, not in committed files.
- **Infrastructure details** — internal hostnames, IP ranges, VPN configs, cluster names, cloud project IDs. Keep these in `~/.config/zsh/private.zsh` (not tracked).

When writing skills, examples, or documentation: use generic placeholder names (`myapp`, `myorg`, `your-repo`) rather than real project or employer names.

## README

Keep `README.md` up to date when making structural changes: adding or removing skills, new LaunchAgents, new config sections, changes to the package registry design, or anything that affects how someone would use or contribute to this repo. The README is the primary entry point for external readers.
