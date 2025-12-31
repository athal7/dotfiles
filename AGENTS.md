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
4. Update `README.md` and `AGENTS.md` files when functionality changes

## Host-Specific Files (NOT managed by chezmoi)

These files are created once but not tracked:
- `~/.env` - API keys and secrets (loaded by direnv)
- `~/.config/opencode/opencode.json` - model configuration
- `~/.config/opencode/AGENTS.local.md` - machine-specific context (auto-discovered)

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
| `dot_local/bin/` | Custom scripts (`gh-pr-poll`) |
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

- `worktrees` - Concurrent branch development using git worktrees or devcontainer clones
