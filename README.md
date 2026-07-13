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
- **Automation**
  - [Calendar](dot_local/lib/cal/__main__.py)
  - [Homebridge](dot_homebridge/)
  - [LaunchAgents](dot_config/launchd-yaml/agents.yaml) — scheduled macOS tasks defined declaratively in [`dot_config/launchd-yaml/agents.yaml`](dot_config/launchd-yaml/agents.yaml) (generated to plists via yq + plutil), including a daily 7am production-error triage (`fix-prod-errors`) that dispatches worktree fix sessions, a monthly spec-compliance audit (`audit`), a weekly Sunday cross-repo friction-hotspot refactor dispatcher (`refactor-hotspots`) that tracks dispatches in [`dot_config/opencode/create_hotspot-dispatch-log.json`](dot_config/opencode/create_hotspot-dispatch-log.json) to dedup repeat proposals, a weekly Sunday disk-space cleanup (`cleanup`), and a 15-minute `kb-zoom-capture` that carves recent Zoom meeting transcripts out of the ephemeral "My Notes" cache into `~/Documents/Zoom` so the daily `kb-enrich` job can distill them
- [Packages](.chezmoidata/packages.yaml)

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for required values (name, email, code directory, GitHub token). Optional integrations can be added by editing `~/.config/chezmoi/chezmoi.toml` after init — see [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl).

## Machine-specific config

Per-machine values live in `~/.local/share/chezmoi/.chezmoidata/local.yaml`. Copy [`local.yaml.example`](local.yaml.example) and fill in your values.
