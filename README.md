# athal7's dotfiles

A personal macOS development environment managed with [chezmoi](https://chezmoi.io). Review the configuration before applying: it installs software, changes settings, and starts background services.

## What's included

- [Zsh](dot_zshrc.tmpl), [Neovim](dot_config/nvim/), Git, and Ghostty.
- [One package registry](.chezmoidata/packages.yaml) for Homebrew, mise, and release downloads.
- [OMP](dot_config/omp/agent/), [MCP servers](.chezmoidata/mcp.yaml), [shared skills](dot_agents/skills/), and [AoE session management](dot_config/agent-of-empires/config.toml.tmpl).
- [LaunchAgents](dot_config/launchd-yaml/agents.yaml.tmpl) for maintenance, updates, and local services.
- [Colima containers](dot_colima/default/colima.yaml), [Homebridge](dot_config/homebridge/), and Naya Create keyboard settings.

## Setup

Install chezmoi and initialize the source without applying it:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init athal7
cd "$(chezmoi source-path)"
cp local.yaml.example .chezmoidata/local.yaml
```

Fill in [machine-specific values](local.yaml.example) in `.chezmoidata/local.yaml`. That file is gitignored, but isn't a secret store.

Before applying on an existing machine, set `umask = 0o077` in the active chezmoi TOML config without running `chezmoi init` (which regenerates it). Managed files become `0600` and directories `0700`, including external app bundles:

```sh
config="$(chezmoi data | jq -r '.chezmoi.configFile')"
yq -i -p=toml -o=toml '.umask = 63' "$config"
```

Also check for these existing-machine risks:

- If `~/.agent-of-empires/` exists, copy its complete contents to `~/.config/agent-of-empires/` before the first apply. AoE switches as soon as the destination exists. Verify `aoe list` and `aoe settings explain session.default_tool` before removing the old tree.
- If Homebridge uses `~/.homebridge`, stop its LaunchAgent, back up any existing `~/.config/homebridge`, and move the entire legacy directory there. Verify `config.json` parses before restarting.
- Colima cannot shrink disks. If the existing VM is larger than the managed 64 GiB default, raise the [profile's disk size](dot_colima/default/colima.yaml) to at least its current size. Review `colima status` and free space before a planned restart.

Preview the changes, then apply:

```sh
chezmoi diff
chezmoi apply
```

## Making changes

Edit the source files in this repository. From a worktree, preview that worktree explicitly:

```sh
chezmoi diff -S "$PWD"
chezmoi apply --dry-run --verbose -S "$PWD"
```

Land committed changes with `chezmoi-deploy <branch>`, not a pull request. It rebases onto `main` if needed, fast-forward-merges, applies, and pushes `main`. A bare `chezmoi apply` reads the primary checkout, not your worktree.

## Credentials

Keep secrets in Apple Passwords or 1Password, never tracked files or `.chezmoidata/local.yaml`. For noninteractive access, `keychain_env` reads macOS Keychain items under service `chezmoi`. In a trusted repository's untracked `.envrc`:

```sh
source "$HOME/.envrc"
keychain_env MYAPP_API_KEY myapp_api_key
```

Review it, then run `direnv allow`. Shell startup doesn't load credentials globally. Alternatively, keep 1Password references in an ignored `fnox.local.toml` and use `fnox exec -- <command>` for command-scoped credentials.

## Naya Create keyboard

Open the downloaded `~/Applications/OpenFlow-*.dmg` and copy `OpenFlow.app` into `~/Applications`. Grant Create Companion Input Monitoring and Accessibility permissions in macOS settings.

Open OpenFlow manually, then run `chezmoi apply` to load the repository profile. GUI edits to OpenFlow and Create Companion are captured as local Git commits; review them before deploying. The watchers don't push. If GUI and repository edits conflict, resolve the reported conflict before applying again.

**Applying dotfiles never flashes the keyboard.** Review profiles before writing to a device, and keep NayaFlow installed until OpenFlow's firmware and recovery support is verified for your hardware.
