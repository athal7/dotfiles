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
- Automation: [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) run the weekday [daily maintenance](dot_agents/prompts/daily-maintenance.md) session for independent production-error triage and KB enrichment, a separate daily Homebrew update and upgrade at 04:00, and weekly cleanup of old Chrome signing clones, idle worktrees, build artifacts, and disconnected development databases. The repo also configures an [attention dashboard](dot_config/attention/config.json.tmpl), [calendar tools](https://github.com/athal7/cal), and [Homebridge](dot_config/homebridge/).
- Packages: [one registry](.chezmoidata/packages.yaml) for Homebrew, mise, the pinned OpenJev Python service, and GitHub releases, with [external downloads](.chezmoiexternal.toml.tmpl). The `cal-automation` package is installed via mise; its [private configuration](dot_config/cal/private_config.json.tmpl) renders from `.chezmoidata/local.yaml` to `~/.config/cal/config.json`. The pinned `codebase-memory-mcp` npm tool is also installed via mise with its native-binary postinstall script explicitly allowed, avoiding an `npx` wrapper per OMP session.
- Containers: Docker CLI and Compose use [Colima](https://github.com/abiosoft/colima). Its LaunchAgent starts a default Docker VM with 4 GiB of memory and a 30 GiB disk limit; shells point `DOCKER_HOST` at `$HOME/.colima/default/docker.sock`. Set `DOCKER_HOST` after shell startup to use another daemon. Compose is exposed through `~/.docker/cli-plugins/docker-compose` without replacing `~/.docker/config.json`. A container with `/var/run/docker.sock` mounted can control sibling containers; treat the mount as privileged. Apple Container remains installed independently, and Colima does not migrate or delete its data.
- Knowledge-base collectors: [definitions](dot_config/kb/collectors/) deploy to `~/.config/kb/collectors/`.

The KB Markdown vault is the canonical source for collected facts and evidence. OMP Mnemopi stores curated agent-learned insights only, with automatic retention disabled and project-tagged memories enabled for cross-project recall.

## OMP and AoE

`omp` uses `~/.config/omp/` as its global root and `~/.config/omp/agent/` for agent data; AoE launches sessions with those paths. OMP credentials use the Keychain-backed secret configuration. AoE Serve binds to loopback behind private Tailscale Serve and uses a Keychain passphrase for its dashboard, not a URL token.

The local `judge` role uses OpenJev's native `POST /v1/systemone` API, not chat prompting. The package install script creates a pinned Python 3.12 environment at `~/.local/share/openjev/venv` before `com.$USER.openjev` starts on `127.0.0.1:8091`. Its first start downloads the MLX weights. The LaunchAgent limits MLX's buffer cache to 4 GiB; OpenJev reports a 23.5-GiB working set with that limit on a 48-GiB M4 Pro. Check `GET http://127.0.0.1:8091/health` and `~/Library/Logs/openjev.error.log` after deployment; the judge is not available until model loading completes.

OMP uses native write approval with explicit bash, browser, eval, hub, task, and write allows. OMP's native GitHub integration is disabled. The Bash policy prompts before each `gh` command. The configured official GitHub MCP is always enabled with selected toolsets and tools; mutation-shaped MCP tool names are matched against repository-owned globs and rendered as exact OMP approval keys. Its writes still require approval for the exact target and payload. Git push and chezmoi-deploy (which applies and pushes main) also prompt. Eval remains allowed and system instructions prohibit using it to bypass the `gh` prompt.

GitHub uses the official remote MCP at https://api.githubcopilot.com/mcp/. Selected read tools cover PR details, combined status and check runs, review threads/comments, Actions workflows/runs/jobs and logs, issues, commit/branch metadata, and repository/code search. Direct commit-status reads outside a PR and generic REST/GraphQL queries are not exposed. Selected writes (comments, review operations, reviewer requests, review-thread resolution, and workflow dispatch) prompt through glob-expanded exact-name policies. The remote uses the GitHub identity authorized through OMP; ensure it can access both organization scopes. For an uncovered endpoint, use `gh` via Bash; every command prompts. Do not use OMP's native GitHub tool.

OMP and scheduled KB enrichment enable every configured MCP server while preserving each tool allowlist, headers, and write-approval policy. Connectors that require credentials or environment URLs still need those values configured. The optional Runlayer MCP entries for GitHub are not used; the remaining Runlayer connectors stay independently configured.
AoE stores configuration, plugins, profiles, and runtime state under `~/.config/agent-of-empires/`. On an existing machine, copy the complete `~/.agent-of-empires/` tree there **before** applying chezmoi: AoE switches to XDG as soon as the new directory exists. Check the migration with `aoe settings explain session.default_tool` and `aoe list` before removing the legacy tree. The tmux status line is minimal; use `C-b s` or `C-b w` to select a session or window.

AoE plugins are declared in the [package registry](.chezmoidata/packages.yaml) and their enablement and capability grants in the [AoE configuration](dot_config/agent-of-empires/modify_config.toml). The [web UI state template](dot_config/agent-of-empires/modify_state.toml) pins the mobile terminal key row while preserving AoE's other runtime and UI state. The Attention plugin displays prioritized items in each session pane.

Homebridge stores its data at `~/.config/homebridge`. On a machine still using `~/.homebridge`, stop Homebridge before migrating the entire directory, preserve any existing destination as a backup, and check that the moved `config.json` parses before restarting it.

## Optional MCP setup

For higher Context7 quotas, create a free key at [Context7](https://context7.com/dashboard) and store it in macOS Keychain:

```bash
security add-generic-password -U -s context7 -a api-key -w
```

The final `-w` prompts for the key rather than putting it in shell history. Without a Keychain item under service `context7`, Context7 remains available anonymously. Chezmoi renders the key into private `~/.config/omp/agent/mcp.json`; after adding or rotating it, run `chezmoi apply` and `/mcp reload` in OMP.

The official GitHub MCP is enabled by default and uses OMP remote authentication with the GitHub identity you authorize. Its toolset and tool allowlist live in .chezmoidata/mcp.yaml; selected write operations prompt through glob-expanded approval policies. Confirm that the identity can access both organization scopes before using it.

The `codebase-memory` MCP server keeps a local index under `~/.cache/codebase-memory-mcp`. New-project auto-indexing is off by default: run its `index_repository` tool once per project. Separate worktrees have separate indexes.
