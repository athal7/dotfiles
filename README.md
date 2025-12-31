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

## OpenCode

**Agent instructions**: Global instructions in `~/.config/opencode/AGENTS.md` apply to all sessions. Repository-specific instructions in `AGENTS.md` at repo root.

**Subagents** (delegated via Task tool):
- `architect` - Design questions, tradeoffs, system boundaries
- `pm` - Tickets, docs, thinking frameworks
- `review` - Code review (read-only)

**Commands**: `/screencast` - Record a Playwright demo

**Skills**:
- `worktrees` - Concurrent branch development (git worktrees or devcontainer clones)

## Devcontainer Multi-Instance

Run multiple devcontainer instances simultaneously with auto-assigned ports. See [athal7/devcontainer-multi](https://github.com/athal7/devcontainer-multi) for usage.

## gh-pr-poll

Checks GitHub for PRs needing attention:
- Review requested → starts `review` subagent
- Changes requested → opens in a worktree

```bash
gh-pr-poll              # Run once
gh-pr-poll --dry-run    # Preview
launchctl load ~/Library/LaunchAgents/com.gh-pr-poll.plist  # Auto-run
```
