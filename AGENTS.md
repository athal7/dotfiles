# Chezmoi Dotfiles Repository

This repo manages `~` via chezmoi. Edit source files here, run `chezmoi apply` to deploy.

**After every commit in this repo: run `chezmoi apply`.** Changes are not live until applied — deployed files under `~/.agents/`, `~/.config/`, etc. will be out of sync otherwise. Do this before handing back to the user.

**`chezmoi apply` may restart the opencode server** if LaunchAgent plists change. Skills, capabilities, and AGENTS.md do not trigger a restart — opencode reads those fresh per-session. When in doubt, use the PTY approach: load the `chezmoi` skill and follow the safe apply workflow.

## Structure

- **`dot_*`** — home directory files and directories (shell, git, editors, app configs)
- **`dot_config/opencode/`** — OpenCode config: model, MCPs, plugins, permissions, agent instructions
- **`dot_agents/skills/`** — agent skills deployed to `~/.agents/skills/`
- **`Library/LaunchAgents/`** — macOS services (opencode web on port 4096)
- **`.chezmoidata/packages.yaml`** — single package registry: brew, cask, mise, github releases
- **`.chezmoiexternal.toml.tmpl`** — generated from packages.yaml, drives chezmoi-native GitHub release downloads
- **`.chezmoiscripts/`** — run on apply: brew bundle, launchagent bootstrap

## Packages

All packages are declared in `.chezmoidata/packages.yaml` under `brews`, `casks`, `mise`, or `github_releases`. The install scripts and external file are generated from it — edit only the registry.

## OpenCode Config

MCPs, plugins, and permissions are all in `opencode.json`. Skills live in `dot_agents/skills/` — edit here, not in `~/.agents/skills/`.

**Keep the global `AGENTS.md.tmpl` lean.** Resist adding DO/DO NOT lists to `dot_config/opencode/AGENTS.md.tmpl`. Long instruction files degrade agent performance — prefer skills and progressive context loading instead.

## Public Repo — Privacy Guidelines

This is a **public repository**. Before committing any content, check for:

- **Work-specific content** — employer names, internal project names, org names, team names, internal URLs, internal hostnames, internal tool names. Replace with generic equivalents (e.g. `myapp`, `myorg`, `your-work-email`).
- **Secrets** — API keys, tokens, passwords, credentials. These must never appear in committed files. Use `promptStringOnce` in `.chezmoi.toml.tmpl` and `modify_private_dot_env.tmpl` for anything sensitive.
- **Personal identifiers** — email addresses, Slack user IDs, Linear team IDs, phone numbers. These belong in chezmoi data, not in committed files.
- **Infrastructure details** — internal hostnames, IP ranges, VPN configs, cluster names, cloud project IDs. Keep these in `~/.config/zsh/private.zsh` (not tracked).

When writing skills, examples, or documentation: use generic placeholder names (`myapp`, `myorg`, `your-repo`) rather than real project or employer names.

## README

Keep `README.md` up to date when making structural changes: adding or removing skills, new LaunchAgents, new config sections, changes to the package registry design, or anything that affects how someone would use or contribute to this repo. The README is the primary entry point for external readers.

## Presentation

`index.html` at the repo root is a slide deck describing this workflow, served via GitHub Pages at `https://athal7.github.io/dotfiles/`. Keep it in sync with the skills:

- **Skill added or removed** — update the inventory slide and the pipeline slide
- **Skill behavior changes significantly** — update the slide that covers that skill
- **Workflow structure changes** (e.g. new phase, skill dissolved) — update the relevant step slides and the closing summary

## Chezmoi Gotchas

- **`.chezmoidata` values are plain data** — template expressions like `{{ .chezmoi.arch }}` inside YAML string values are not evaluated. Arch/OS logic must live in the `.tmpl` file itself.
- **`.app` bundles via `chezmoiexternal`** — use `type = "archive"` with target `"Applications/<AppName>.app"` (unique TOML key per app) and `stripComponents = 1` to strip the archive's root directory. The zip contains e.g. `NayaFlow-Beta.app/Contents/...` — without `stripComponents = 1` the app ends up double-nested. TOML does not allow duplicate keys, so each app needs its own unique target path.

- **LaunchAgent binary path changes** — after moving a binary (e.g., brew → `~/.local/bin`), `launchctl bootout` + `bootstrap` is required to pick up the new plist; `kickstart` alone is not sufficient if the service is crash-looping.

- **Updating a plist** — `chezmoi apply` only bootstraps agents that aren't loaded. To pick up plist changes on a running agent: `launchctl kickstart -k gui/$(id -u)/<label>`

- **Deleting a managed file** — `chezmoi apply` does not remove files whose source entry was deleted. Use `chezmoi destroy <target>` to remove both the source entry and the deployed file in one step. Do not use `rm` directly — the file will reappear on the next apply. Note: files managed via `.chezmoiexternal.toml.tmpl` (e.g. `~/.agents/skills/ical-cli`) cannot be destroyed this way — chezmoi owns them; remove the external entry instead.
