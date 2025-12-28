## athal7's dotfiles

Using [chezmoi](https://chezmoi.io) for dotfile management.

## What's Included

- **Shell**: zsh with starship prompt, direnv
- **OpenCode**: Generic agents (pm, dev, qa, review, devex) without tool-specific details
- **Development**: Docker, Git, GitHub CLI, VS Code
- **Secrets**: Pattern like `.zshrc` + `.secret` - shared config in Chezmoi, machine-specific in local files

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Or if you already have Chezmoi installed:
```bash
chezmoi init --apply athal7
```

Then fill in machine-specific details:
- Edit `~/.secret` for environment variables and API keys
- Edit `~/AGENTS_LOCAL.md` for OpenCode project context (tool names, project details)

## OpenCode Configuration

Four primary agents are installed to `~/.config/opencode/agent/`:
- `dev` - Developer (features, bugs, deployment)
- `devex` - DevEx Engineer (laptop config, tooling)
- `pm` - Product Manager (tickets, docs, thinking frameworks)
- `review` - Code Reviewer (friendly, concise feedback, read-only)

**Usage**: Press **Tab** to cycle through agents. The active agent shows in the lower right corner.

Global commands are installed to `~/.config/opencode/command/`:
- `/screencast` - Record a Playwright screencast demo of a localhost workflow

**Usage**: Type `/screencast` in any agent to invoke the command.

**Privacy**: Agents are generic. Tool names and project details go in `~/AGENTS_LOCAL.md` which stays on your machine only.

Global safety rules are in `~/.config/opencode/AGENTS.md` and apply to all agents. 

Agents use the globally configured model. Optionally configure per-agent models in your machine-specific `~/.config/opencode/opencode.json`.

## GitHub PR Automation

`gh-pr-poll` checks GitHub for PRs needing attention and spawns OpenCode agents with suggested actions. Agents wait for your approval before submitting reviews or committing changes.

- **Review requested** → starts `review` agent
- **Changes requested on your PR** → starts `dev` agent in a git worktree

```bash
gh-pr-poll              # Run once
gh-pr-poll --dry-run    # Show what would happen
gh-pr-poll --status     # Show processed PRs
gh-pr-poll --sessions   # List active tmux sessions
gh-pr-poll --reset      # Clear state, reprocess all
```

To run automatically every 2 minutes:
```bash
launchctl load ~/Library/LaunchAgents/com.gh-pr-poll.plist
```

Set `GH_PR_POLL_OPENCODE_DIR` in `~/.secret` to run all sessions in one directory (e.g., `~/Documents/GitHub`).

## Concurrent Devcontainers

For projects with devcontainers, you can run multiple branches simultaneously using git worktrees with unique ports.

**How it works:**
1. Create a worktree for each branch: `git worktree add ../repo-branch branch-name`
2. Each worktree gets a `.devcontainer/devcontainer.local.json` with a unique port
3. The global gitignore excludes `devcontainer.local.json` so it's not committed

**Automatic setup:** When `gh-pr-poll` creates a worktree for a PR, it automatically assigns the next available port (checking both config files and active listeners).

**Manual setup:** Create `.devcontainer/devcontainer.local.json` in your worktree:
```json
{
  "name": "Repo - branch-name",
  "runArgs": ["-p", "3001:3000"],
  "forwardPorts": [3001]
}
```

**Port assignment:**
- Main repo: 3000
- Worktrees: 3001, 3002, etc.

Find an open port:
```bash
# Check assigned ports
grep -h '"runArgs"' ../*/.devcontainer/devcontainer.local.json 2>/dev/null

# Check if port is in use
lsof -i :3001 -sTCP:LISTEN
```
