# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io).

## What's here

- **Dev environment**
  - Shell — [zshrc](dot_zshrc.tmpl), [zshenv](dot_zshenv.tmpl), [zprofile](dot_zprofile.tmpl)
  - [Editor](dot_config/nvim/)
  - [Git](dot_config/git/)
  - [Terminal](dot_config/ghostty/)
- **AI tooling**
  - [OpenCode config](dot_config/opencode/opencode.json.tmpl)
  - [Agent skills](skills/) — knowledge base, communication, code review, and more
- **Automation**
  - [Calendar](dot_local/lib/cal/__main__.py)
  - [Homebridge](dot_homebridge/)
  - [LaunchAgents](Library/LaunchAgents/)
- [Packages](.chezmoidata/packages.yaml)

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for required values (name, email, code directory, GitHub token). Optional integrations can be added by editing `~/.config/chezmoi/chezmoi.toml` after init — see [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl).

## Machine-specific config

Per-machine values live in `~/.local/share/chezmoi/.chezmoidata/local.yaml`. Copy [`local.yaml.example`](local.yaml.example) and fill in your values.
