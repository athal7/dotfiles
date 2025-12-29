## athal7's dotfiles

Using [chezmoi](https://chezmoi.io) for dotfile management.

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Then fill in machine-specific details:
- `~/.secret` - environment variables and API keys
- `~/AGENTS_LOCAL.md` - project context (tool names, repos, etc.)
- `~/.config/opencode/opencode.json` - model configuration

## OpenCode

**Agent instructions**: Global instructions in `~/.config/opencode/AGENTS.md` apply to all sessions. Repository-specific instructions in `AGENTS.md` at repo root.

**Subagents** (delegated via Task tool):
- `pm` - Tickets, docs, thinking frameworks
- `review` - Code review (read-only)

**Commands**: `/screencast` - Record a Playwright demo

**Skills**:
- `worktree-setup` - Git worktrees for concurrent development
- `devcontainer-ports` - Port config for multiple devcontainers

## gh-pr-poll

Checks GitHub for PRs needing attention:
- Review requested → starts `review` subagent
- Changes requested → opens in a worktree

```bash
gh-pr-poll              # Run once
gh-pr-poll --dry-run    # Preview
launchctl load ~/Library/LaunchAgents/com.gh-pr-poll.plist  # Auto-run
```
