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

These files are created once but not tracked:
- `~/.env` - API keys and secrets (loaded by direnv)
- `~/.config/opencode/opencode.json` - model configuration
- `~/.config/opencode/AGENTS.local.md` - machine-specific context (auto-discovered)

## Key Locations

| Location | Contents |
|----------|----------|
| `dot_zshrc.tmpl` | Shell configuration |
| `dot_config/starship.toml` | Prompt configuration |
| `dot_local/bin/` | Custom scripts (`gh-pr-poll`) |
| `.chezmoitemplates/Brewfile` | Homebrew packages (includes `opencode` and `opencode-desktop`) |

## OpenCode Configuration

**Global config** (`~/.config/opencode/`):
- `opencode.json` - model settings (host-specific, not in chezmoi)
- `AGENTS.md` - instructions for all agents
- `agent/` - primary agent overrides and subagents
- `command/` - global slash commands

**Per-project config** (`.opencode/` in repo root):
- `command/` - project-specific slash commands
- Custom tools, agents, themes

## Agent Override Structure

When modifying agent behavior, choose the right location:

| File | Purpose |
|------|---------|
| `dot_config/opencode/AGENTS.md` | Universal rules (safety, env vars, quality) |
| `dot_config/opencode/agent/build.md` | Development workflow: TDD, commits, PRs, code quality |
| `dot_config/opencode/agent/plan.md` | Read-only analysis and planning mode |
| `dot_config/opencode/agent/architect.md` | Design decisions and tradeoffs |
| `dot_config/opencode/agent/review.md` | Code review feedback |
| `dot_config/opencode/agent/pm.md` | Issues, specs, documentation

**When updating agent instructions**:
1. Review all agents to ensure appropriate placement
2. Check for conflicting or duplicative guidance across agents
3. Clean up as appropriate
4. Update this table if adding/removing/renaming agents

## Skills

- `worktrees` - Concurrent branch development using git worktrees or devcontainer clones
