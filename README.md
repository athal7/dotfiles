## athal7's dotfiles

Using [chezmoi](https://chezmoi.io) for dotfile management.

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Then fill in machine-specific details:
- `~/.env` - environment variables and API keys (loaded by direnv)
- `~/.config/opencode/opencode.json` - model configuration
- `~/.config/opencode/AGENTS.local.md` - machine-specific context (auto-discovered)

Automatic setup includes:
- ✅ Homebrew packages via Brewfile (including `opencode` and `opencode-desktop`)

## OpenCode

**Agent instructions**: Global instructions in `~/.config/opencode/AGENTS.md` apply to all sessions. Repository-specific instructions in `AGENTS.md` at repo root.

**Agents**:
- `build` - TDD workflow, commits, PRs, code quality (primary)
- `plan` - Delegation hub: analysis, research, coordination

**Subagents** (delegated via plan):
- `architect` - Design questions, tradeoffs, system boundaries
- `pm` - Customer context, requirements, problem definition
- `docs` - READMEs, guides, ADRs, markdown documentation
- `explore` - Codebase investigation

**Commands**:
- `/review` - Code review (commit, branch, PR, or uncommitted changes)
- `/screencast` - Record a Playwright demo
- `/todo` - Manage todo list

**Skills**:
- `opencode-devcontainers` - Concurrent branch development using devcontainer clones
