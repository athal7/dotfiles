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
4. Update `README.md` for material changes

## Host-Specific Files (NOT managed by chezmoi)

These files are created once but not tracked:
- `~/.secret` - API keys and secrets (sourced by zshrc)
- `~/.config/opencode/opencode.json` - model configuration
- `~/AGENTS_LOCAL.md` - project context for agents

## Key Locations

| Location | Contents |
|----------|----------|
| `dot_config/opencode/AGENTS.md` | Global agent instructions |
| `dot_config/opencode/agent/` | Subagent definitions (`pm`, `review`) |
| `dot_config/opencode/command/` | Slash commands |
| `dot_config/opencode/skill/` | Loadable skills |
| `dot_config/opencode/plugin/` | Hooks and plugins |
| `dot_zshrc.tmpl` | Shell configuration |
| `dot_config/starship.toml` | Prompt configuration |
| `.chezmoitemplates/Brewfile` | Homebrew packages (includes `opencode` and `opencode-desktop`) |

## OpenCode Configuration

**Global config** (`~/.config/opencode/`):
- `opencode.json` - model settings (host-specific, not in chezmoi)
- `AGENTS.md` - instructions for all agents
- `agent/` - subagent definitions
- `command/` - global slash commands

**Per-project config** (`.opencode/` in repo root):
- `command/` - project-specific slash commands
- Custom tools, agents, themes

## Skills

Use the `worktree-setup` and `devcontainer-ports` skills for concurrent branch development with devcontainers.
