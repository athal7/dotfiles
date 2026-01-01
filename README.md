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

Automatic setup includes:
- ✅ Homebrew packages via Brewfile
- ✅ ocdc polling service (`brew services start ocdc`)
- ✅ Poll configurations for GitHub and Linear
- ✅ OpenCode plugin for ocdc integration

## OpenCode

**Agent instructions**: Global instructions in `~/.config/opencode/AGENTS.md` apply to all sessions. Repository-specific instructions in `AGENTS.md` at repo root.

**Primary agents** (switch modes):
- `build` - TDD workflow, commits, PRs, code quality
- `plan` - Read-only analysis and planning

**Subagents** (delegated via Task tool):
- `architect` - Design questions, tradeoffs, system boundaries
- `pm` - Tickets, docs, thinking frameworks
- `review` - Code review (read-only)

**Commands**:
- `/screencast` - Record a Playwright demo
- `/todo` - Manage todo list

**Skills**:
- `ocdc` - Concurrent branch development using devcontainer clones
