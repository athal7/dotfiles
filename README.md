# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io).

## What's here

- **Dev environment**
  - Shell — [zshrc](dot_zshrc.tmpl), [zshenv](dot_zshenv.tmpl), [zprofile](dot_zprofile.tmpl)
  - [Editor](dot_config/nvim/)
  - [Git](dot_config/git/)
- **AI tooling**
  - [OpenCode config](dot_config/opencode/opencode.json.tmpl)
  - [Agent skills](skills/) — knowledge base, communication, code review, and more. QA produces an AC-organized evidence report; the `qa-report-publish` skill delivers it to your own PR's description. Static and blast-radius code review is not performed inline; it happens automatically on the pushed PR.
  - [MCP registry](.chezmoidata/mcp.yaml) — MCP servers and their optional wrapping subagents (Slack, GitHub, Linear, Google Workspace, Atlassian, Zoom), declared declaratively and rendered into `opencode.json` via the `opencode-mcp-{servers,tools,agents}` template partials.
  - [Agent of Empires config](dot_agent-of-empires/config.toml) — aoe's global user config, chezmoi-managed and deployed to `~/.agent-of-empires/config.toml`.
  - [Per-org model classes](.chezmoidata/agents.yaml) — agents declare a `class` (`default`/`smol`/`slow`/`plan`, omp's native modelRoles vocabulary) resolved via `model_class`; a per-org override in `local.yaml`'s `orgs.<org>.model_class` is injected at aoe session launch by [`aoe-model-class`](dot_local/bin/executable_aoe-model-class) (an `on_launch` host hook) into gitignored, project-local `.opencode/opencode.json` and `.omp/config.yml`.
  - [Local model registry](.chezmoidata/models.yaml) — single source of truth for the locally-hosted mlx model (host, port, hf repo, context window); feeds omp's [`models.yml`](dot_omp/private_agent/models.yml.tmpl), opencode's mlx provider block, and the `mlx-server` LaunchAgent's `--model`/`--host`/`--port` args.
  - [omp model config](dot_omp/private_agent/models.yml.tmpl) — points omp's local `mlx` provider at the same `mlx_lm.server` endpoint (`127.0.0.1:8091`) opencode uses; chezmoi-managed counterpart to opencode's `mlx` provider block.
  - omp feature parity — a `run_onchange` generator materializes real subagent files at `~/.omp/agent/agents/*.md` from `.chezmoidata/agents.yaml` (chezmoi has no native one-source-to-N-files mapping, so this is a plain script, not a template), and a second `run_onchange` script pushes global settings (`bash.patterns`, `tools.approvalMode`, `task.disabledAgents`, `compaction.strategy`) via `omp config set`.
- **Automation**
  - [Calendar](dot_local/lib/cal/__main__.py)
  - [Attention triage dashboard](dot_config/attention/config.json.tmpl) — config for the [`attention`](https://github.com/athal7/attention) CLI (installed via `athal7/tap/attention`), a prioritized calendar/reminders/GitHub/Linear triage dashboard with an fzf-driven hotkey UI; this file just supplies the calendar/reminder-list names flagged `attention_check: true` plus codeDir and a Linear token.
  - [Homebridge](dot_homebridge/)
  - [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) — scheduled macOS tasks defined declaratively in [`dot_config/launchd-yaml/agents.yaml.tmpl`](dot_config/launchd-yaml/agents.yaml.tmpl) (generated to plists via yq + plutil), including a daily 7am production-error triage (`fix-prod-errors`) that dispatches worktree fix sessions, a monthly spec-compliance audit (`audit`), a weekly Sunday cross-repo friction-hotspot refactor dispatcher (`refactor-hotspots`) that tracks dispatches in [`dot_config/opencode/create_hotspot-dispatch-log.json`](dot_config/opencode/create_hotspot-dispatch-log.json) to dedup repeat proposals, a weekly Sunday disk-space cleanup (`cleanup`), a 15-minute `kb-zoom-capture` that carves recent Zoom meeting transcripts out of the ephemeral "My Notes" cache into `~/Documents/Zoom` so the daily `kb-enrich` job can distill them.
- [Packages](.chezmoidata/packages.yaml)

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for required values (name, email, code directory, GitHub token). Optional integrations can be added by editing `~/.config/chezmoi/chezmoi.toml` after init — see [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl).

## Machine-specific config

Per-machine values live in `~/.local/share/chezmoi/.chezmoidata/local.yaml`. Copy [`local.yaml.example`](local.yaml.example) and fill in your values.
