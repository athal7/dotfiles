# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io).

## What's here

- **Dev environment**
  - Shell — [zshrc](dot_zshrc.tmpl), [zshenv](dot_zshenv.tmpl), [zprofile](dot_zprofile.tmpl)
  - [Editor](dot_config/nvim/)
  - [Git](dot_config/git/)
- **AI tooling**
  - [agentcfg registry](dot_config/agentcfg/) — the single source of truth for both opencode's and omp's agent/workflow config, applied by [`agentcfg`](https://github.com/athal7/agentcfg) via one `run_onchange` script ([`run_onchange_after_agentcfg-apply.sh.tmpl`](.chezmoiscripts/run_onchange_after_agentcfg-apply.sh.tmpl)). [`workflow.yaml.tmpl`](dot_config/agentcfg/workflow.yaml.tmpl) declares every agent/step once (prompt, permissions, MCP grants, role); [`mcp_servers.yaml`](dot_config/agentcfg/mcp_servers.yaml) declares every MCP server once; [`agentcfg.yaml.tmpl`](dot_config/agentcfg/agentcfg.yaml.tmpl)'s `harnesses.<id>.extra` covers the config surface agentcfg's registry model has no dedicated field for (opencode.json's static server/plugin/provider/formatter/lsp blocks; omp's `tools.approvalMode`/`task.disabledAgents`/`compaction.strategy` settings). Neither harness's native config file is separately hand-templated anymore — agentcfg owns each one outright, so there's no two-writer race between a chezmoi template and agentcfg's own merge.
  - [Agent skills](dot_agents/skills/) — authored skills are managed directly by chezmoi; agentcfg commands and external installers own distinct sibling directories under `~/.agents/skills/`.
  - [Agent of Empires config](dot_agent-of-empires/config.toml) — aoe's global user config, chezmoi-managed and deployed to `~/.agent-of-empires/config.toml`.
  - [Freebuff](https://freebuff.com/) — installed through mise and available to Agent of Empires as the opt-in `freebuff` terminal agent (`aoe add --tool freebuff`).
  - Per-org model routing — private defaults and organization overrides live only in gitignored `.chezmoidata/local.yaml`; [`agentcfg.yaml.tmpl`](dot_config/agentcfg/agentcfg.yaml.tmpl) compiles them into agentcfg contexts, and [`aoe-model-class`](dot_local/bin/executable_aoe-model-class) applies the matching context to each launched repository's gitignored OpenCode and OMP config.
  - [Local model configuration](local.yaml.example) — `local_model` is the single source of truth for the locally-hosted mlx model (endpoint, repo, context window, server generation cap, and lower agent request cap). It feeds omp's [`models.yml`](dot_omp/private_agent/models.yml.tmpl), the agentcfg-owned opencode mlx provider block, and the `mlx-server` LaunchAgent.
  - [omp model config](dot_omp/private_agent/models.yml.tmpl) — points omp's local `mlx` provider at the same `mlx_lm.server` endpoint (`127.0.0.1:8091`) opencode uses; chezmoi-managed counterpart to the agentcfg-owned opencode `mlx` provider block.
  - [Generic tool permissions](.chezmoidata/permissions.yaml) — cross-harness defaults for built-in tools and external-directory access; separate from package Bash rules and MCP classifications.
- **Automation**
  - [Calendar](dot_local/lib/cal/__main__.py)
  - [Attention triage dashboard](dot_config/attention/config.json.tmpl) — config for the [`attention`](https://github.com/athal7/attention) CLI (installed via `athal7/tap/attention`), a prioritized calendar/reminders/GitHub/Linear triage dashboard with an fzf-driven hotkey UI; it supplies the calendar/reminder-list names flagged `attention_check: true`, codeDir, a Linear token, a Lumen shortcut, and an AOE-session action on every item type. Starting an AOE session prompts for a customizable session message; calendar and reminder sessions use AOE scratch projects.
  - [Homebridge](dot_homebridge/)
  - [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) — scheduled macOS tasks defined declaratively in [`dot_config/launchd-yaml/agents.yaml.tmpl`](dot_config/launchd-yaml/agents.yaml.tmpl) (generated to plists via yq + plutil), including a daily 7am production-error triage (`fix-prod-errors`) that dispatches worktree fix sessions, a monthly spec-compliance audit (`audit`), a weekly Sunday cross-repo friction-hotspot refactor dispatcher (`refactor-hotspots`) that tracks dispatches in [`dot_config/opencode/create_hotspot-dispatch-log.json`](dot_config/opencode/create_hotspot-dispatch-log.json) to dedup repeat proposals, a weekly Sunday disk-space cleanup (`cleanup`), a 15-minute `kb-zoom-capture` that carves recent Zoom meeting transcripts out of the ephemeral "My Notes" cache into `~/Documents/Zoom` so the daily `kb-enrich` job can distill them.
- [Packages](.chezmoidata/packages.yaml) — dependency registry and source of truth for package-owned Bash permission rules; [`bash.yaml.tmpl`](dot_config/agentcfg/bash.yaml.tmpl) renders those rules into the OMP policy, while [`mcp_servers.yaml`](dot_config/agentcfg/mcp_servers.yaml) owns MCP tool classifications.

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for required values (name, email, code directory, GitHub token). Optional integrations can be added by editing `~/.config/chezmoi/chezmoi.toml` after init — see [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl).

## Machine-specific config

Per-machine values live in `~/.local/share/chezmoi/.chezmoidata/local.yaml`. Copy [`local.yaml.example`](local.yaml.example) and fill in your values.
