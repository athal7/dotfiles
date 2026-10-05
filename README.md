# athal7's dotfiles

A macOS development environment managed with [chezmoi](https://chezmoi.io).

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Copy [`local.yaml.example`](local.yaml.example) to `.chezmoidata/local.yaml` and fill in machine-specific values. Run `chezmoi apply` after changing the source files.

## What's included

- Development tools: [shell](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), and [Git](dot_config/git/).
- AI tools: [OMP configuration](dot_config/omp/private_agent/), [MCP servers](.chezmoidata/mcp.yaml), and [shared skills](dot_agents/skills/) installed at `~/.agents/skills/`. AoE (Agent of Empires) manages OMP sessions.
- Local AI: [OpenJev](https://github.com/razorback16/openjev) runs an MLX System One server on loopback for OMP's native [judge role](dot_config/omp/private_agent/private_config.yml.tmpl); its pinned Python environment is installed from the [package registry](.chezmoidata/packages.yaml) before the [LaunchAgent](dot_config/launchd-yaml/agents.yaml.tmpl) starts.
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) run the weekday [daily maintenance](dot_agents/prompts/daily-maintenance.md) session and weekly cleanup of old Chrome signing clones, idle worktrees, build artifacts, and disconnected development databases. The repo also configures an [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](https://github.com/athal7/cal), and [Homebridge](dot_config/homebridge/).
- Packages: [one registry](.chezmoidata/packages.yaml) for Homebrew, mise, the pinned OpenJev Python service, and GitHub releases, with [external downloads](.chezmoiexternal.toml.tmpl). The `cal-automation` package is installed via mise; its [private configuration](dot_config/cal/private_config.json.tmpl) renders from `.chezmoidata/local.yaml` to `~/.config/cal/config.json`.
- Containers: Docker CLI and Compose use [Colima](https://github.com/abiosoft/colima). Its LaunchAgent starts a default Docker VM with 4 GiB of memory and a 30 GiB disk limit; shells point `DOCKER_HOST` at `$HOME/.colima/default/docker.sock`. Set `DOCKER_HOST` after shell startup to use another daemon. Compose is exposed through `~/.docker/cli-plugins/docker-compose` without replacing `~/.docker/config.json`. A container with `/var/run/docker.sock` mounted can control sibling containers; treat the mount as privileged. Apple Container remains installed independently, and Colima does not migrate or delete its data.
- Knowledge-base collectors: [definitions](dot_config/kb/collectors/) deploy to `~/.config/kb/collectors/`.

The KB Markdown vault is the canonical source for collected facts and evidence. OMP Mnemopi stores curated agent-learned insights only, with automatic retention disabled and project-tagged memories enabled for cross-project recall.

## OMP and AoE

`omp` uses `~/.config/omp/` as its global root and `~/.config/omp/agent/` for agent data; AoE launches sessions with those paths. OMP credentials use the Keychain-backed secret configuration. AoE Serve binds to loopback behind private Tailscale Serve and uses a Keychain passphrase for its dashboard, not a URL token.

The local `judge` role uses OpenJev's native `POST /v1/systemone` API, not chat prompting. The package install script creates a pinned Python 3.12 environment at `~/.local/share/openjev/venv` before `com.$USER.openjev` starts on `127.0.0.1:8091`. Its first start downloads the MLX weights. The LaunchAgent limits MLX's buffer cache to 4 GiB; OpenJev reports a 23.5-GiB working set with that limit on a 48-GiB M4 Pro. Check `GET http://127.0.0.1:8091/health` and `~/Library/Logs/openjev.error.log` after deployment; the judge is not available until model loading completes.

OMP uses native `write` approval with explicit `bash: allow`, `browser: allow`, `eval: allow`, `hub: allow`, `task: allow`, and `write: allow` overrides. Prefer native GitHub tools for operations they support; shell rules prompt for `gh api` because request arguments can send writes, including when the request is intended as a read. Native GitHub writes and PR creation/review use the execution tier and require approval; shell rules also prompt for `git push`, `chezmoi-deploy` (which applies and pushes `main`), and `gh pr create/edit/review/comment/ready/close/lock/merge/reopen/revert/unlock/update-branch`. The generated approval map prompts for registered remote MCP tools whose names indicate mutation, while `approval_allow` keeps specifically approved read-only tools allowed. BigQuery and PagerDuty query tools also prompt because they can send writes through their query arguments.

Scheduled KB enrichment's private OMP overlay enables every configured MCP server and renders configured authentication headers into the overlay. Configured name-based mutation prompts still apply; they are not a network sandbox.

AoE stores configuration, plugins, profiles, and runtime state under `~/.config/agent-of-empires/`. On an existing machine, copy the complete `~/.agent-of-empires/` tree there **before** applying chezmoi: AoE switches to XDG as soon as the new directory exists. Check the migration with `aoe settings explain session.default_tool` and `aoe list` before removing the legacy tree. The tmux status line is minimal; use `C-b s` or `C-b w` to select a session or window.

AoE plugins are declared in the [package registry](.chezmoidata/packages.yaml) and their enablement and capability grants in the [AoE configuration](dot_config/agent-of-empires/modify_config.toml). The Attention plugin displays prioritized items in each session pane.

Homebridge stores its data at `~/.config/homebridge`. On a machine still using `~/.homebridge`, stop Homebridge before migrating the entire directory, preserve any existing destination as a backup, and check that the moved `config.json` parses before restarting it.

## Optional MCP setup

For higher Context7 quotas, create a free key at [Context7](https://context7.com/dashboard) and store it in macOS Keychain:

```bash
security add-generic-password -U -s context7 -a api-key -w
```

The final `-w` prompts for the key rather than putting it in shell history. Without a Keychain item under service `context7`, Context7 remains available anonymously. Chezmoi renders the key into private `~/.config/omp/agent/mcp.json`; after adding or rotating it, run `chezmoi apply` and `/mcp reload` in OMP.

The `codebase-memory` MCP server keeps a local index under `~/.cache/codebase-memory-mcp`. New-project auto-indexing is off by default: run its `index_repository` tool once per project. Separate worktrees have separate indexes.
