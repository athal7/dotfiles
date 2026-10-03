# athal7's dotfiles

A macOS development environment managed with [chezmoi](https://chezmoi.io).

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Copy [`local.yaml.example`](local.yaml.example) to `.chezmoidata/local.yaml` and fill in machine-specific values. Run `chezmoi apply` after changing the source files.

## What's included

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: [OMP configuration](dot_config/omp/private_agent/), [MCP servers](.chezmoidata/mcp.yaml), and [shared skills](dot_agents/skills/) installed at `~/.agents/skills/`. AoE (Agent of Empires) manages OMP sessions; upstream Pi is available separately.
- Local AI: [model configuration](dot_config/omp/private_agent/models.yml.tmpl) and a [llama.cpp service](dot_config/launchd-yaml/agents.yaml.tmpl).
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) run the weekday [daily maintenance](dot_agents/prompts/daily-maintenance.md) session and weekly cleanup of old Chrome signing clones, idle worktrees, build artifacts, and disconnected development databases. The repo also configures an [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](https://github.com/athal7/cal), and [Homebridge](dot_config/homebridge/).
- Packages: [one registry](.chezmoidata/packages.yaml) for Homebrew, mise, and GitHub releases, with [external downloads](.chezmoiexternal.toml.tmpl). The `cal-automation` package is installed via mise; its [private configuration](dot_config/cal/private_config.json.tmpl) renders from `.chezmoidata/local.yaml` to `~/.config/cal/config.json`.
- Containers: Docker CLI and Compose use [Colima](https://github.com/abiosoft/colima). Its LaunchAgent starts a default Docker VM with 4 GiB of memory and a 30 GiB disk limit; shells point `DOCKER_HOST` at `$HOME/.colima/default/docker.sock`. Set `DOCKER_HOST` after shell startup to use another daemon. Compose is exposed through `~/.docker/cli-plugins/docker-compose` without replacing `~/.docker/config.json`. A container with `/var/run/docker.sock` mounted can control sibling containers; treat the mount as privileged. Apple Container remains installed independently, and Colima does not migrate or delete its data.
- Knowledge-base collectors: [definitions](dot_config/kb/collectors/) deploy to `~/.config/kb/collectors/`.

## OMP, AoE, and Pi

`omp` uses `~/.config/omp/` as its global root and `~/.config/omp/agent/` for agent data. AoE launches OMP sessions with those paths and loads an optional Anthropic API key from Keychain; restart running sessions after adding or rotating the key. AoE Serve binds to loopback behind private Tailscale Serve and uses a Keychain passphrase for its dashboard, not a URL token.

OMP uses native `yolo` approval for low-friction local work. The [remote-write hook](dot_config/omp/private_agent/hooks/pre/remote-write-approval.ts) prompts for known writes from registered remote MCP servers and recognized shell clients (`git push`, selected `gh` mutations, `curl`, and `xh`). The shared [`approval_allow` registry](.chezmoidata/mcp.yaml) keeps approved read-only MCP calls such as Context7 allowed. This is best-effort, not a network sandbox; unrecognized clients, arbitrary code, and browser actions can still perform remote writes without prompting.

AoE stores configuration, plugins, profiles, and runtime state under `~/.config/agent-of-empires/`. On an existing machine, copy the complete `~/.agent-of-empires/` tree there **before** applying chezmoi: AoE switches to XDG as soon as the new directory exists. Check the migration with `aoe settings explain session.default_tool` and `aoe list` before removing the legacy tree. The tmux status line is minimal; use `C-b s` or `C-b w` to select a session or window.

`pi` is upstream Pi 1.0, separate from OMP: it keeps its own settings, models, packages, and sessions under `~/.pi/agent/`. The [Pi launcher](dot_local/bin/executable_pi) clears inherited OMP `PI_*` variables. Its [settings](dot_pi/private_agent/private_settings.json.tmpl) and [models](dot_pi/private_agent/private_models.json.tmpl) are chezmoi-managed. Pi follows npm releases via mise rather than the potentially older Homebrew formula. When `local_model` is configured, Pi selects llama.cpp as an OpenAI-compatible provider; OMP's model roles, Eval, AoE sessions, and scheduled workflows remain separate.

Pi's native MCP configuration is rendered from the shared registry, keeps credentials command-backed, and exposes only registry-approved tools. Context7 and CQ remain disabled by default; Pi's `/mcp` toggles are independent from OMP.

The managed [`pi-permission-system` extension](dot_pi/private_agent/extensions/pi-permission-system/private_config.json.tmpl) allows file reads/search, tool discovery, and native MCP tools listed in OMP's read-only approval allowlist. Bash, file writes, Codemode, extension tools, and mutating, ambiguous, or unknown MCP calls ask for approval; `.env` paths are denied except examples. Pi reuses OMP's read-only MCP allowlist and shared mutation-verb list, but cannot inspect HTTP methods or GraphQL arguments as OMP's pre-tool hook does. The package registry manages Pi and `pi-permission-system`.

Homebridge stores its data at `~/.config/homebridge`. On a machine still using `~/.homebridge`, stop Homebridge before migrating the entire directory, preserve any existing destination as a backup, and check that the moved `config.json` parses before restarting it.

## Optional MCP setup

For higher Context7 quotas, create a free key at [Context7](https://context7.com/dashboard) and store it in macOS Keychain:

```bash
security add-generic-password -U -s context7 -a api-key -w
```

The final `-w` prompts for the key rather than putting it in shell history. Without a Keychain item under service `context7`, Context7 remains available anonymously. Chezmoi renders the key into private `~/.config/omp/agent/mcp.json`; after adding or rotating it, run `chezmoi apply` and `/mcp reload` in OMP.

The `codebase-memory` MCP server keeps a local index under `~/.cache/codebase-memory-mcp`. New-project auto-indexing is off by default: run its `index_repository` tool once per project. Separate worktrees have separate indexes.
