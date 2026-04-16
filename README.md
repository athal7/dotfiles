# athal7's dotfiles

Manages `~` on macOS via [chezmoi](https://chezmoi.io). Covers shell, editor, AI tooling, calendar automation, and a library of AI agent skills.

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
- **Agent skills** — 26 skills for OpenCode and compatible agents (`dot_agents/skills/`)

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

26 [Agent Skills](https://agentskills.io)-compatible skills deployed to `~/.agents/skills/`. Works with [OpenCode](https://opencode.ai) and any compatible agent. See [`dot_agents/skills/README.md`](dot_agents/skills/README.md) for the full list and install instructions.

Skills use a capability-based composition system — workflow skills declare what they `requires`, and a [`capabilities.yaml`](dot_agents/capabilities.yaml) manifest binds capabilities to providers (a skill, `cli://<binary>`, or `mcp://<server>`). This lets workflow skills stay tool-agnostic: swap Linear for Jira by changing one line.

> **Spec proposal:** This composition model is proposed as an extension to the agentskills format at [agentskills/agentskills#311](https://github.com/agentskills/agentskills/discussions/311).

### Using skills without these dotfiles

Install individual skills via [chezmoi external](https://www.chezmoi.io/reference/special-files/chezmoiexternal-format/) by adding entries to your `.chezmoiexternal.toml`:

```toml
[".agents/skills/commit"]
    type = "archive"
    url = "https://github.com/athal7/dotfiles/archive/refs/heads/main.tar.gz"
    stripComponents = 3
    include = ["*/dot_agents/skills/commit/**"]
    targetPath = ".agents/skills/commit"
    refreshPeriod = "168h"
```

`stripComponents = 3` strips the `athal7-dotfiles-<sha>/dot_agents/skills/` prefix so the skill lands directly at the `targetPath`.

To use workflow skills that have `requires`, create `~/.agents/capabilities.yaml` mapping each capability to a provider:

```yaml
# Skill — loads SKILL.md instructions
logs: elasticsearch

# CLI — agent calls the binary directly via Bash
calendar: cli://ical

# MCP tool — activates tool calls on demand
pull-requests: mcp://github
```

Your agent also needs to know how to resolve capabilities. Add this to your global agent instructions (e.g. `~/.config/opencode/AGENTS.md`):

```markdown
## Skill Capabilities

When you load a skill that has `requires` in its metadata, read `~/.agents/capabilities.yaml`
to resolve each capability. If the value is a skill name, load that skill. If it starts with
`cli://`, call that binary via Bash and read its `--help` on demand. If it starts with `mcp://`,
activate that tool. If a capability has no mapping, ask the user which provider to use.
```

#### Leverage chezmoidata to manage multiple skills

If you want to install many skills from the same repo without repeating the archive entry for each, you can drive the external config from chezmoi data. Add this to your `.chezmoiexternal.toml.tmpl`:

```gotmpl
{{ range $url, $data := .agentSkills }}
{{ range $skill := $data.skills }}
[".agents/skills/{{ $skill }}"]
    type = "{{ with index $data "type" }}{{ $data.type }}{{ else }}archive{{ end }}"
    url = "{{ $url }}"
    stripComponents = {{ with index $data "stripComponents" }}{{ $data.stripComponents }}{{ else }}3{{ end }}
    include = ["*/dot_agents/skills/{{ $skill }}/**"]
    targetPath = ".agents/skills/{{ $skill }}"
    refreshPeriod = "{{ with index $data "refreshPeriod" }}{{ $data.refreshPeriod }}{{ else }}168h{{ end }}"

{{ end }}
{{ end }}
```

Then declare the skills you want in your `.chezmoidata/skills.yaml` (or any chezmoidata file). The full list of available skills is in [`dot_agents/skills/`](dot_agents/skills/):

```yaml
agentSkills:
  "https://github.com/athal7/dotfiles/archive/refs/heads/main.tar.gz":
    type: archive
    stripComponents: 3
    skills:
      - attention
      - commit
      - context-log
      - gh
      - git-spice
      - google-docs
      - learn
      - plan
      - review
      - slack
      - tdd
      - thinking-tools
      - writing
```
