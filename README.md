# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io). Covers shell, editor, AI tooling, calendar automation, and a library of AI agent skills.

## Quick start

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

You'll be prompted for secrets and machine-specific values during init. See [chezmoi's password manager docs](https://www.chezmoi.io/user-guide/password-managers/) for how to integrate with your preferred secret store.

## What's configured

- **Shell** — zsh (`dot_zshrc.tmpl`, `dot_zshenv.tmpl`, `dot_zprofile.tmpl`)
- **Editor** — Neovim (`dot_config/nvim/`)
- **Git** — config, aliases, hooks (`dot_config/git/`)
- **Terminal** — Ghostty (`dot_config/ghostty/`)
- **AI tooling** — OpenCode config, MCPs, plugins, agent instructions (`dot_config/opencode/`)
- **Packages** — brew, cask, mise, GitHub releases (`dot_chezmoidata/packages.yaml`)
- **Calendar automation** — sync, lunch guard, family scheduler (`dot_local/bin/`, `Library/LaunchAgents/`)
- **Homebridge** — Google Nest via HomeKit (`dot_homebridge/`)
- **macOS services** — LaunchAgents for background processes (`Library/LaunchAgents/`)
- **Agent skills** — 30+ skills for OpenCode and compatible agents (`dot_agents/skills/`)

## chezmoi source file conventions

chezmoi uses filename prefixes to encode behavior. Key ones used here:

| Source name | Deploys to |
|---|---|
| `dot_foo` | `~/.foo` |
| `dot_config/` | `~/.config/` |
| `dot_agents/` | `~/.agents/` |
| `dot_local/` | `~/.local/` |
| `foo.tmpl` | `foo` (processed as a Go template) |
| `private_foo` | `foo` (deployed with `chmod 600`) |
| `run_once_*.sh` | Script run once on first apply |
| `run_onchange_*.sh` | Script run when its contents change |

See the [chezmoi source state reference](https://www.chezmoi.io/reference/source-state-attributes/) for the full list.

## Agent Skills

30+ [Agent Skills](https://agentskills.io)-compatible skills deployed to `~/.agents/skills/`. Works with [OpenCode](https://opencode.ai) and any compatible agent. See [`dot_agents/skills/README.md`](dot_agents/skills/README.md) for the full list and install instructions.

Skills are designed around a capability-based composition system — integration skills declare what they `provides`, workflow skills declare what they `requires`, and a [`capabilities.yaml`](dot_agents/capabilities.yaml) manifest binds them together. This lets workflow skills stay tool-agnostic: swap Linear for Jira by changing one line. The design is proposed as a spec extension at [agentskills/agentskills#311](https://github.com/agentskills/agentskills/discussions/311).

### Using skills without these dotfiles

Install individual skills via [chezmoi external](https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/) by adding entries to your `.chezmoiexternal.toml`:

```toml
["commit-skill"]
    type = "archive"
    url = "https://github.com/athal7/dotfiles/archive/refs/heads/main.tar.gz"
    stripComponents = 3
    include = ["*/dot_agents/skills/commit/**"]
    targetPath = ".agents/skills/commit"
    refreshPeriod = "168h"
```

`stripComponents = 3` strips the `athal7-dotfiles-<sha>/dot_agents/skills/` prefix so the skill lands directly at the `targetPath`.

To use workflow skills that have `requires`, also install [`dot_agents/capabilities.yaml`](dot_agents/capabilities.yaml) and update it to point at your preferred tools:

```toml
["capabilities"]
    type = "file"
    url = "https://github.com/athal7/dotfiles/raw/main/dot_agents/capabilities.yaml"
    targetPath = ".agents/capabilities.yaml"
    refreshPeriod = "168h"
```

Then edit `~/.agents/capabilities.yaml` to bind capabilities to your preferred skills.
