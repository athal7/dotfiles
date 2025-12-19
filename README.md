## athal7's dotfiles

Using [chezmoi](https://chezmoi.io) for dotfile management.

## What's Included

- **Shell**: zsh with starship prompt, direnv
- **OpenCode**: Generic agents (pm, dev, review, devex) without tool-specific details
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

**Privacy**: Agents are generic. Tool names and project details go in `~/AGENTS_LOCAL.md` which stays on your machine only.

Global safety rules are in `~/.config/opencode/AGENTS.md` and apply to all agents. 

Agents use the globally configured model. Optionally configure per-agent models in your machine-specific `~/.config/opencode/opencode.json`:
