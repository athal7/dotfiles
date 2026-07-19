# Chezmoi Dotfiles Repository

This repo manages `~` via chezmoi. Edit source files here, run `chezmoi apply` to deploy.

**No pull requests — deploy is the ship step.** Land changes with `chezmoi-deploy <branch>`: it fast-forward-merges the branch into the primary checkout's `main`, runs `chezmoi apply`, and pushes `main` to origin as a mirror. Only `chezmoi apply` mutates your live `~`. Load the chezmoi skill for verify-render-only and deploy mechanics.

**No tracked issues required.** This is a personal dotfiles repo with no team to coordinate with — skip the `/implement` workflow's Issue phase and go straight to Workspace setup.

**`chezmoi apply` auto-deploys and reloads changed LaunchAgents.** The `run_onchange_after_aa-launch-agents.sh` generator renders every plist from `dot_config/launchd-yaml/agents.yaml` (yq → plutil), then reloads only agents whose plist content actually changed and prunes agents deleted from the YAML — so unchanged agents are never restarted. The individual plists are NOT chezmoi-managed; the generator owns them. To force-run a scheduled job for testing, you can still kickstart it manually: `launchctl kickstart -k gui/$(id -u)/<label>`.

## Structure

- **`dot_*`** — home directory files and directories (shell, git, editors, app configs)
- **`dot_config/opencode/`** — OpenCode config: model, MCPs, plugins, permissions, agent instructions
- **`skills/`** — agent skills deployed to `~/.agents/skills/`
- **`dot_config/launchd-yaml/agents.yaml`** — macOS services (scheduled jobs and daemons) defined declaratively; deployed, reloaded, and pruned by the `.chezmoiscripts/run_onchange_after_aa-launch-agents.sh` generator (renders via yq → plutil, reloads only changed agents, removes agents deleted from the YAML). Individual plists are not chezmoi-managed. One of these agents (`aoe-serve` on :4097, `personal` profile) runs `aoe serve`, localhost-only with `--no-auth`, foreground under launchd's `KeepAlive` (no `--daemon` flag — that self-detaches and fights launchd's supervision). Its purpose is enabling the local TUI's structured (ACP) session view: the TUI is an ACP client of `aoe serve` and does not auto-spawn one, so without a running daemon it bails with a "no daemon running" hint. There is only ever one `aoe serve` process on the machine — its daemon lock (`serve.pid`/`serve.url`) lives in a single global app dir with zero profile-awareness (`get_app_dir()` in aoe's `src/session/mod.rs`), so `-p` does not let two profiles run concurrently; `personal` was the profile chosen. This is unrelated to the phone/remote-access use case that previously used port 4097 via a Tailscale proxy outside this registry; that use case was retired 2026-07-11 and remains retired — this agent is local-only, no tunnel. The `personal` profile's `default_tool` is `pi` (`dot_agent-of-empires/profiles/personal/modify_config.toml`); the `pi-acp` adapter and `@earendil-works/pi-coding-agent` it needs to render in structured view are mise-managed npm globals declared in `.chezmoidata/packages.yaml`.
- **`.chezmoidata/packages.yaml`** — single package registry: brew, cask, mise, github releases
- **`.chezmoidata/mcp.yaml`** — MCP server connections and their optional wrapping subagents, rendered into `opencode.json` via the `opencode-mcp-{servers,tools,agents}` template partials (in `.chezmoitemplates/`). `servers[]` drives both the `mcp` block and the global tool deny-list; `agents[]` (optional per server) drives the wrapping subagent definitions. Adding a "reach service X via MCP" subagent is a registry entry here plus a hand-authored prompt at `dot_config/opencode/prompts/<agent>.md`.
- **`.chezmoiexternal.toml.tmpl`** — generated from packages.yaml, drives chezmoi-native GitHub release downloads
- **`.chezmoiscripts/`** — run on apply: brew bundle, skill sync

## Packages

All packages are declared in `.chezmoidata/packages.yaml` under `brews`, `casks`, `mise`, `github_releases`, or `aoe_plugins` (aoe/Agent of Empires plugins, installed/updated via `run_onchange_after_plugins-aoe.sh.tmpl`). The install scripts and external file are generated from it — edit only the registry.

## OpenCode Config

MCPs, plugins, and permissions are all in `opencode.json`. Skills live in `skills/` — edit here, not in `~/.agents/skills/`.

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
