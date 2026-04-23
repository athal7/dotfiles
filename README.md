# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io). Covers shell, editor, AI tooling, calendar automation, and a library of AI agent skills.

## Workflow Demo

**[athal7.github.io/dotfiles](https://athal7.github.io/dotfiles/)** — a slide deck walking through how the agent skills fit together into a daily development workflow.

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for a few required values (name, email, code directory, GitHub token, calendar names). Optional integrations — Slack, Figma, Elasticsearch, Linear, ICS feeds, etc. — can be added by editing `~/.config/chezmoi/chezmoi.toml` after init. See the commented sections in [`.chezmoi.toml.tmpl`](.chezmoi.toml.tmpl) for the full list.

## What's configured

- **Shell** — zsh (`dot_zshrc.tmpl`, `dot_zshenv.tmpl`, `dot_zprofile.tmpl`)
- **Editor** — Neovim (`dot_config/nvim/`)
- **Git** — config, aliases, hooks (`dot_config/git/`)
- **Terminal** — Ghostty (`dot_config/ghostty/`)
- **AI tooling** — OpenCode config, MCPs, plugins, agent instructions (`dot_config/opencode/`)
- **Packages** — brew, cask, mise, GitHub releases (`.chezmoidata/packages.yaml`)
- **Calendar automation** — sync, lunch guard, family scheduler (`dot_local/bin/`, `Library/LaunchAgents/`)
- **Homebridge** — Google Nest via HomeKit (`dot_homebridge/`)
- **macOS services** — LaunchAgents for background processes (`Library/LaunchAgents/`)
- **Agent skills** — see [`skills/`](skills/)

## Agent Skills

[Agent Skills](https://agentskills.io)-compatible skills deployed to `~/.agents/skills/`. Works with [OpenCode](https://opencode.ai) and any compatible agent.

Skills use a capability-based composition system — workflow skills declare what they `requires`, and [`skills/capabilities.yaml`](skills/capabilities.yaml) binds capabilities to providers (a skill, `cli://<binary>`, or `mcp://<server>`). This lets workflow skills stay tool-agnostic: swap Linear for Jira by changing one line. See [agentskills/agentskills#311](https://github.com/agentskills/agentskills/discussions/311) for the spec proposal.

### Installing individual skills

**With the GitHub CLI:**

```bash
gh skill install athal7/dotfiles commit
gh skill install athal7/dotfiles review
```

**With chezmoi** — declare skills in `.chezmoidata/packages.yaml` and use a `run_onchange_` script to install and update them weekly. See [our sync script](.chezmoiscripts/run_onchange_after_sync-and-validate-skills.sh.tmpl) as a reference:

```yaml
# .chezmoidata/packages.yaml
packages:
  skills:
    - repo: athal7/dotfiles
      skill: commit
    - repo: athal7/dotfiles
      skill: review
```
