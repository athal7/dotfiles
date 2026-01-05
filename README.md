## athal7's dotfiles

Using [chezmoi](https://chezmoi.io) for dotfile management.

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Then fill in machine-specific details:
- `~/.env` - environment variables and API keys (loaded by direnv)
- `~/.config/opencode/AGENTS.local.md` - machine-specific context (auto-discovered)
- `~/.config/opencode/opencode.json` - model configuration
- `~/.config/opencode-pilot/repos.yaml` - optional polling configurations (not synced)

Automatic setup includes:
- ✅ Homebrew packages via Brewfile
- ✅ OpenCode plugins installed via npm (`npx opencode-pilot setup`, `npx opencode-devcontainers setup`)

## OpenCode

**Agent instructions**: Global instructions in `~/.config/opencode/AGENTS.md` apply to all sessions. Repository-specific instructions in `AGENTS.md` at repo root.

**Primary agents** (switch modes):
- `build` - TDD workflow, commits, PRs, code quality
- `plan` - Read-only analysis and planning

**Subagents** (delegated via Task tool):
- `architect` - Design questions, tradeoffs, system boundaries
- `pm` - Tickets, docs, thinking frameworks

**Commands**:
- `/review` - Code review (commit, branch, PR, or uncommitted changes)
- `/screencast` - Record a Playwright demo
- `/todo` - Manage todo list

**Skills**:
- `opencode-devcontainers` - Concurrent branch development using devcontainer clones
