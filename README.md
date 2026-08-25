# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io).

## What's here

- **Dev environment**
  - Shell — [zshrc](dot_zshrc.tmpl), [zshenv](dot_zshenv.tmpl), [zprofile](dot_zprofile.tmpl)
  - [Editor](dot_config/nvim/)
  - [Git](dot_config/git/)
- **AI tooling**
  - [OMP configuration](dot_omp/private_agent/private_modify_config.yml.tmpl) — ChezMoi enforces OMP tool and Bash approval policy while OMP retains its runtime settings.
  - [MCP registry](.chezmoidata/mcp.yaml) — server transport, command, URL, header, model-exclusion, and tool inventory data rendered into OMP configuration.
  - [OMP lead prompt](dot_omp/private_agent/APPEND_SYSTEM.md) — direct OMP system prompt.
  - [Agent skills](dot_agents/skills/) — authored skills are managed directly by chezmoi; externally installed skills own distinct sibling directories under `~/.agents/skills/`.
  - [Agent of Empires config](dot_agent-of-empires/modify_config.toml) — aoe's global user config, chezmoi-managed and deployed to `~/.agent-of-empires/config.toml`.
  - [Freebuff](https://freebuff.com/) — installed through mise and available to Agent of Empires as the opt-in `freebuff` terminal agent (`aoe add --tool freebuff`).
  - Per-org model routing — private defaults and organization overrides live only in gitignored `.chezmoidata/local.yaml`.
  - [Local model configuration](local.yaml.example) — `local_model` is the single source of truth for the local Apple Silicon model endpoint, runtime, repo, context window, server generation cap, and lower agent request cap. It feeds OMP's [`models.yml`](dot_omp/private_agent/models.yml.tmpl) and the local-model LaunchAgent.
  - [OMP model config](dot_omp/private_agent/models.yml.tmpl) — points OMP's local `mlx` provider at the shared local endpoint.
- **Automation**
  - [Calendar](dot_local/lib/cal/__main__.py)
  - [Attention triage dashboard](dot_config/attention/config.json.tmpl) — config for the [`attention`](https://github.com/athal7/attention) CLI (installed via `athal7/tap/attention`), a prioritized calendar/reminders/GitHub/Linear dashboard. It opens a grouped terminal overview for time-sensitive items, personal GitHub work, work reviews, work queues, and schedule/reminders. A selected group opens the existing fzf action list. The config derives the personal GitHub prefix from the authenticated `gh` CLI account, including new repositories. It supplies calendar/reminder-list names flagged `attention_check: true`, codeDir, a Linear token, a Lumen shortcut, and an AOE-session action on every item type. Starting an AOE session prompts for a customizable session message; calendar and reminder sessions use AOE scratch projects.
  - [Homebridge](dot_homebridge/)
  - [Agent of Empires Cron](https://github.com/agent-of-empires/plugin-cron) — the managed `agent-of-empires.cron` plugin starts weekday knowledge enrichment and production-error triage scratch sessions, plus a weekly system audit. The `aoe-serve` LaunchAgent keeps its local, token-protected host running after login.
  - [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) — scheduled macOS host tasks defined declaratively in [`dot_config/launchd-yaml/agents.yaml.tmpl`](dot_config/launchd-yaml/agents.yaml.tmpl) and generated to plists via yq + plutil.
- [Packages](.chezmoidata/packages.yaml) — dependency registry. `.chezmoidata/mcp.yaml` owns shared MCP data.

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for required values (name, email, code directory, GitHub token). Optional integrations can be added by editing `~/.config/chezmoi/chezmoi.toml` after init — see [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl).

## Machine-specific config

Per-machine values live in `~/.local/share/chezmoi/.chezmoidata/local.yaml`. Copy [`local.yaml.example`](local.yaml.example) and fill in your values.
