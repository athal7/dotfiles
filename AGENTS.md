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
- `opencode.json` - models, MCPs, tools config (managed by chezmoi)
- `AGENTS.md` - instructions for all agents
- `agent/` - primary agent overrides and subagents
- `command/` - global slash commands
- `mcps/` - custom MCP servers (granola-mcp.py)

**Per-project config** (`.opencode/` in repo root):
- `command/` - project-specific slash commands
- Custom tools, agents, themes

## Agent Override Structure

| Location | Purpose |
|----------|---------|
| `dot_config/opencode/AGENTS.md.tmpl` | Universal rules (safety, env vars, CLI tools, quality) - auto-generates subagent/command lists |
| `dot_config/opencode/agent/build.md` | Primary agent: TDD workflow, commits, PRs |
| `dot_config/opencode/agent/plan.md.tmpl` | Delegation hub - auto-generates subagent list |
| `dot_config/opencode/agent/*.md` | Subagents (mode: subagent) and local agents (model: ollama/*) |
| `dot_config/opencode/command/*.md` | Slash commands |

**Adding a new agent/command**:
1. Create the `.md` file with YAML frontmatter including `description:` and `mode:`
2. Run `chezmoi apply` - lists auto-update in AGENTS.md, plan.md, and README.md

**Frontmatter fields used for templating**:
- `description:` - Short description (required for listing)
- `mode:` - `primary`, `subagent`, or `all` (determines categorization)
- `model:` - If starts with `ollama/`, listed under "Local agents"

## Skills

- `opencode-devcontainers` - Concurrent branch development using devcontainer clones (for devcontainer projects)
