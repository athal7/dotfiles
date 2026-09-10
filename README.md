# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io).

## What's here

- **Dev environment**
  - Shell — [zshrc](dot_zshrc.tmpl), [zshenv](dot_zshenv.tmpl), [zprofile](dot_zprofile.tmpl)
  - [Editor](dot_config/nvim/)
  - [Git](dot_config/git/)
- **AI tooling**
  - [OMP configuration](dot_omp/private_agent/modify_private_config.yml) — ChezMoi enforces OMP tool and Bash approval policy while OMP retains its runtime settings.
  - [MCP registry](.chezmoidata/mcp.yaml) — server transport, command, URL, header, model-exclusion, and tool inventory data rendered into OMP configuration.
  - [OMP lead prompt](dot_omp/private_agent/APPEND_SYSTEM.md) — direct OMP system prompt.
  - [Agent skills](dot_agents/skills/) — authored skills are managed directly by chezmoi; externally installed skills own distinct sibling directories under `~/.agents/skills/`.
  - [Agent of Empires config](dot_agent-of-empires/modify_config.toml) — aoe's global user config, chezmoi-managed and deployed to `~/.agent-of-empires/config.toml`. Its `Alt+l` shortcut resolves the Homebrew package prefix, so it runs `lumen` without a link or `PATH` entry.
  - [Linear custom script](dot_linear/coding-tools.json.tmpl) — opens a Linear issue in a new AOE worktree session. Enable **Custom script** in Linear **Settings > Code & reviews > Configure coding tools**. Then select **Work on issue → Custom script**. The script requires the selected work directory to be the primary checkout of a Git repository.
  - [Freebuff](https://freebuff.com/) — installed through mise and available to Agent of Empires as the opt-in `freebuff` terminal agent (`aoe add --tool freebuff`).
  - Per-org model routing — private defaults, organization overrides, and the shared OMP prewalk target live only in gitignored `.chezmoidata/local.yaml`.
  - KB enrichment MCP isolation — the scheduled job uses the main OMP profile for shared authentication and installs a collector-only project MCP overlay in its private scratch session. Normal and review sessions do not load those integration schemas.
  - [Local model configuration](local.yaml.example) — `local_model` is the single source of truth for the local Apple Silicon model endpoint, runtime, repo, context window, output cap, cache limit, compaction tail, and cloud compaction model. It feeds OMP's [`models.yml`](dot_omp/private_agent/models.yml.tmpl), the `aoe-model-class` project reconciler, and the `llama-server` LaunchAgent.
  - [Local GGUF server](dot_config/launchd-yaml/agents.yaml.tmpl) — the `llama.cpp` package runs Qwen 30B GGUF with a 32k context, one request slot, prompt caching, a 3 GiB cache limit, full GPU offload, disabled reasoning, and `/metrics`.
  - Knowledge routing — CQ is the local agent index. KB owns ingestion and the upstream local-projection integration. `/kb-enrich` retains semantic extraction, source access classification, approval presentation, and Confluence publication handling. Agents use KB as fallback when CQ cannot answer or projection verification is incomplete. CQ has no remote address, credentials, or drain tool.
- **Automation**
  - [Calendar](dot_local/lib/cal/__main__.py)
  - [Attention triage dashboard](dot_config/attention/config.json.tmpl) — config for the [`attention`](https://github.com/athal7/attention) CLI (installed via `athal7/tap/attention`), a prioritized calendar/reminders/GitHub/Linear dashboard. It opens a grouped terminal overview for time-sensitive items, personal GitHub work, work reviews, work queues, and schedule/reminders. A selected group opens the existing fzf action list. The config derives the personal GitHub prefix from the authenticated `gh` CLI account, including new repositories. It supplies calendar/reminder-list names flagged `attention_check: true`, codeDir, a Linear token, a Lumen shortcut, and an AOE-session action on every item type. Starting an AOE session prompts for a customizable session message; calendar and reminder sessions use AOE scratch projects.
  - [Homebridge](dot_homebridge/)
  - [Scheduled AoE sessions](dot_config/launchd-yaml/agents.yaml.tmpl) — LaunchAgents start tmux-backed OMP sessions for weekday knowledge enrichment and production-error triage, plus the weekly system audit. Production triage starts 15 minutes after enrichment to avoid concurrent AOE launch-hook mutations. Each run has a unique title. The launcher records an opaque per-session correlation token in local state so `/audit` can join scheduled AOE sessions to OMP transcripts. The `aoe-serve` LaunchAgent keeps its local host running after login. Its remote access passphrase is stored in the macOS Keychain.
  - [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) — scheduled macOS host tasks defined declaratively in [`dot_config/launchd-yaml/agents.yaml.tmpl`](dot_config/launchd-yaml/agents.yaml.tmpl) and generated to plists via yq + plutil.
- [Packages](.chezmoidata/packages.yaml) — dependency registry. `.chezmoidata/mcp.yaml` owns shared MCP data.

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for required values (name, email, code directory, GitHub token). Optional integrations can be added by editing `~/.config/chezmoi/chezmoi.toml` after init — see [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl).

## Machine-specific config

Per-machine values live in `~/.local/share/chezmoi/.chezmoidata/local.yaml`. Copy [`local.yaml.example`](local.yaml.example) and fill in your values.
