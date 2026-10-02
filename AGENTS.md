# Chezmoi Dotfiles Repository

This repo manages `~` via chezmoi. Edit source files here, run `chezmoi apply` to deploy.

**No pull requests — deploy is the ship step.** Land changes with `chezmoi-deploy <branch>`: it fast-forward-merges the branch into the primary checkout's `main`, runs `chezmoi apply`, and pushes `main` to origin as a mirror. Only `chezmoi apply` mutates your live `~`. Load the chezmoi skill for verify-render-only and deploy mechanics.

**`chezmoi apply` auto-deploys and reloads changed LaunchAgents.** The source template `.chezmoiscripts/run_onchange_after_zz-launch-agents.sh.tmpl` is the generator; during apply, chezmoi renders and runs that template after package installation, then it delegates to `launchd-yaml apply` to render every plist from `dot_config/launchd-yaml/agents.yaml.tmpl` (yq → plutil), reload only agents whose plist content actually changed, and prune agents deleted from the YAML — so unchanged agents are never restarted. The individual plists are NOT chezmoi-managed; the generator owns them.

## Structure

- **`dot_*`** — home directory files and directories (shell, git, editors, app configs)
- `dot_config/omp/private_agent/` manages OMP config under `~/.config/omp/agent/`; `PI_CONFIG_DIR=.config/omp` selects the global root and `PI_CODING_AGENT_DIR` selects the agent path for shells, AoE sessions, and LaunchAgents.
- **`.chezmoidata/mcp.yaml`** — neutral MCP server data rendered into OMP templates.
- **`dot_agents/skills/`** — authored agent skills managed natively at `~/.agents/skills/`; externally installed skills own separate sibling directories.
- **`dot_config/launchd-yaml/agents.yaml.tmpl`** — macOS services (scheduled jobs and daemons) defined declaratively; deployed, reloaded, and pruned by `.chezmoiscripts/run_onchange_after_zz-launch-agents.sh.tmpl`, which chezmoi renders and runs during apply. Individual plists are not chezmoi-managed.
- **`.chezmoidata/packages.yaml`** — single package registry: brew, cask, mise (including Python tools), github releases
- **`.chezmoidata/local.yaml`** — private machine and organization data, including model defaults and per-org overrides; gitignored and represented publicly only by `local.yaml.example`.
- **`dot_config/cal/private_config.json.tmpl`** — renders the private XDG config for standalone cal from gitignored local data; the package itself does not read chezmoi data.
- **`.chezmoiexternal.toml.tmpl`** — generated from packages.yaml, drives chezmoi-native GitHub release downloads
- **`.chezmoiscripts/`** — run on apply only where generation or an external installer is required

## Packages

All packages are declared in `.chezmoidata/packages.yaml` under `brews`, `casks`, `mise`, `github_releases`, or `aoe_plugins` (aoe/Agent of Empires plugins, installed/updated via `run_onchange_after_plugins-aoe.sh.tmpl`). The install scripts and external file are generated from it — edit only the registry.

## Agent Config

`dot_config/omp/private_agent/private_config.yml` directly manages `~/.config/omp/agent/config.yml`. `dot_config/omp/private_agent/APPEND_SYSTEM.md` owns its system prompt.

## Agent Operating Rules

- OMP MCP server names are selector labels. When referring to exposed MCP tools, use server/tool names with hyphens converted to underscores. Server-specific read-only MCP exceptions belong in that server's `approval_allow` field in `.chezmoidata/mcp.yaml`; do not infer permission from the verb hook's Bash matching, which is a heuristic rather than a shell sandbox.
- Browser use requires affirmative user consent before the first browser API call in each OMP session. This is instruction-based, not enforced by OMP tool approval. Consent does not authorize consequential actions or navigation in the user's visible tab.
- Keep code-review findings unlabeled; prefix only nits with `nit:`. For pull-request reviews, anchor each finding to a diff line when possible.
- Daily maintenance runs production-error triage, KB enrichment, and CQ quality review as independent workstreams. Report outcomes separately; a settled worker or scheduled launcher exit does not establish complete coverage. Unanswered approvals and uncertain writes remain pending; do not retry timed-out writes until their outcome is known. The session uses the KB MCP overlay; KB projections remain governed by KB authorization and verification.
- For GitHub session actions in attention, use a checkout under `codeDir` or a registered AoE project whose GitHub origin matches the item. Register any checkout outside `codeDir` with AoE first.
- Before changing Homebridge's storage path, stop its LaunchAgent; verify `~/.homebridge/config.json` exists and parses. Preserve an existing `~/.config/homebridge` by renaming it to a unique backup, move the complete legacy directory, verify the moved JSON, then restart.

## Public Repo — Privacy Guidelines

This is a **public repository**. Before committing any content, check for:

- **Work-specific content** — employer names, internal project names, org names, team names, internal URLs, internal hostnames, internal tool names. Replace with generic equivalents (e.g. `myapp`, `myorg`, `your-work-email`).
- **Secrets** — API keys, tokens, passwords, credentials. These must never appear in committed files. Use `promptStringOnce` in `.chezmoi.toml.tmpl` and `modify_private_dot_env.tmpl` for anything sensitive.
- **Personal identifiers** — email addresses, Slack user IDs, Linear team IDs, phone numbers. These belong in chezmoi data, not in committed files.
- **Infrastructure details** — internal hostnames, IP ranges, VPN configs, cluster names, cloud project IDs. Keep these in `~/.config/zsh/private.zsh` (not tracked).

When writing skills, examples, or documentation: use generic placeholder names (`myapp`, `myorg`, `your-repo`) rather than real project or employer names.

## README

Keep `README.md` up to date when making structural changes: adding or removing skills, new LaunchAgents, new config sections, changes to the package registry design, or anything that affects how someone would use or contribute to this repo. The README is the primary entry point for external readers; keep it focused on information people need to understand, set up, and use the dotfiles. Agent operating rules belong in this file.
