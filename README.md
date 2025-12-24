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
- **Changes requested on your PR** → starts `dev` agent

```bash
gh-pr-poll              # Run once
gh-pr-poll --dry-run    # Show what would happen
gh-pr-poll --status     # Show processed PRs
gh-pr-poll --reset      # Clear state, reprocess all
```

To run automatically every 2 minutes:
```bash
launchctl load ~/Library/LaunchAgents/com.gh-pr-poll.plist
```

Set `GH_PR_POLL_OPENCODE_DIR` in `~/.secret` to run all sessions in one directory (e.g., `~/Documents/GitHub`).
