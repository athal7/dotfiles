# Chezmoi Dotfiles Repository

This repo manages `~` via chezmoi. Edit source files here, run `chezmoi apply` to deploy.

## Structure

- **`dot_*`** — home directory files and directories (shell, git, editors, app configs)
- **`dot_config/opencode/`** — OpenCode config: model, MCPs, plugins, permissions, agent instructions
- **`dot_agents/skills/`** — agent skills deployed to `~/.agents/skills/`
- **`Library/LaunchAgents/`** — macOS services (opencode web on port 4096)
- **`.chezmoidata/packages.yaml`** — single package registry: brew, cask, mise, github releases
- **`.chezmoiexternal.toml.tmpl`** — generated from packages.yaml, drives chezmoi-native GitHub release downloads
- **`.chezmoiscripts/`** — run on apply: brew bundle, launchagent reload, opencode restart

## Packages

All packages are declared in `.chezmoidata/packages.yaml` under `brews`, `casks`, `mise`, or `github_releases`. The install scripts and external file are generated from it — edit only the registry.

**`description` is the opt-in signal for agent visibility.** Only entries with a `description` field are rendered into `AGENTS.md` (the agent's tool list). Add a description when the tool is agent-invokable from the CLI. Omit it for GUI apps, fonts, menu bar tools, and language runtimes that the agent doesn't call directly.

## OpenCode Config

`opencode.json` is validated against its schema before the web service restarts. If apply succeeds but the server doesn't come back, check the error log and fix the JSON before re-applying.

MCPs, plugins, and permissions are all in `opencode.json`. Skills live in `dot_agents/skills/` — edit here, not in `~/.agents/skills/`.

## Public Repo — Privacy Guidelines

This is a **public repository**. Before committing any content, check for:

- **Work-specific content** — employer names, internal project names, org names, team names, internal URLs, internal hostnames, internal tool names. Replace with generic equivalents (e.g. `myapp`, `myorg`, `your-work-email`).
- **Secrets** — API keys, tokens, passwords, credentials. These must never appear in committed files. Use `promptStringOnce` in `.chezmoi.toml.tmpl` and `modify_private_dot_env.tmpl` for anything sensitive.
- **Personal identifiers** — email addresses, Slack user IDs, Linear team IDs, phone numbers. These belong in chezmoi data, not in committed files.
- **Infrastructure details** — internal hostnames, IP ranges, VPN configs, cluster names, cloud project IDs. Keep these in `~/.config/zsh/private.zsh` (not tracked).

When writing skills, examples, or documentation: use generic placeholder names (`myapp`, `myorg`, `your-repo`) rather than real project or employer names.

## README

Keep `README.md` up to date when making structural changes: adding or removing skills, new LaunchAgents, new config sections, changes to the package registry design, or anything that affects how someone would use or contribute to this repo. The README is the primary entry point for external readers.

## Chezmoi Gotchas

- **`.chezmoidata` values are plain data** — template expressions like `{{ .chezmoi.arch }}` inside YAML string values are not evaluated. Arch/OS logic must live in the `.tmpl` file itself.
- **`.app` bundles via `chezmoiexternal`** — use `type = "archive"` with target `"Applications/<AppName>.app"` (unique TOML key per app) and `stripComponents = 1` to strip the archive's root directory. The zip contains e.g. `NayaFlow-Beta.app/Contents/...` — without `stripComponents = 1` the app ends up double-nested. TOML does not allow duplicate keys, so each app needs its own unique target path.

- **LaunchAgent binary path changes** — after moving a binary (e.g., brew → `~/.local/bin`), `launchctl bootout` + `bootstrap` is required to pick up the new plist; `kickstart` alone is not sufficient if the service is crash-looping.
