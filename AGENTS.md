# Chezmoi Dotfiles Repository

## Chezmoi Workflow

**Always edit source files here**, then run `chezmoi apply`. Never edit target files directly.

**Naming conventions**:
- `dot_` prefix becomes `.` (e.g., `dot_zshrc` -> `~/.zshrc`)
- `.tmpl` extension for templated files
- `executable_` prefix for scripts that need +x
- `create_` prefix for files created only if missing

**Making changes**:
1. Edit files in this repo
2. Run `chezmoi apply` to deploy
3. For new packages, update `.chezmoitemplates/Brewfile`
4. Ensure `README.md` stays up to date with any functionality changes

## Host-Specific Files (NOT managed by chezmoi)

- `~/.env` - API keys and secrets (loaded by direnv)

## Key Locations

| Location | Contents |
|----------|----------|
| `dot_zshrc.tmpl` | Shell configuration |
| `dot_config/starship.toml` | Prompt configuration |
| `.chezmoitemplates/Brewfile` | Homebrew packages (includes `opencode` and `opencode-desktop`) |

## OpenCode Configuration

**Global config** (`~/.config/opencode/`):
- `opencode.json` - models, MCPs, agent config (managed by chezmoi)
- `AGENTS.md` - instructions for all agents
- `command/` - slash commands (`/qa`, `/review`, `/todo`)
- `skill/` - on-demand skills (loaded via skill tool)

**Per-project config** (`.opencode/` in repo root):
- `command/` - project-specific slash commands
- Custom tools, agents, themes

## Agent Structure

| Location | Purpose |
|----------|---------|
| `dot_config/opencode/opencode.json` | Agent config (models, permissions, temperature) |
| `dot_config/opencode/AGENTS.md.tmpl` | Universal rules (safety, CLI tools, task completion) - auto-generates command list |
| `dot_config/opencode/command/*.md` | Slash commands (thin orchestrators that load skills) |
| `dot_config/opencode/skill/*/SKILL.md` | On-demand skills (loaded via skill tool when needed) |

**Adding a new command**:
1. Create `.md` file in `command/` with YAML frontmatter including `description:`
2. Run `chezmoi apply` - command list auto-updates in AGENTS.md

**Adding a new skill**:
1. Create `skill/<name>/SKILL.md` with `name:` and `description:` in frontmatter
2. Run `chezmoi apply` - skill appears in skill tool listing
