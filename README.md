## athal7's dotfiles

Using [chezmoi](https://chezmoi.io) for dotfile management.

## What's Included

- **Shell**: zsh with starship prompt, direnv
- **OpenCode**: Generic personas (pm, dev, review, devex) without tool-specific details
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

Four personas are installed to `~/.opencode/command/`:
- `/pm` - Product Manager (tickets, docs, thinking frameworks)
- `/dev` - Developer (features, bugs, deployment)
- `/review` - Code Reviewer (friendly, concise feedback)
- `/devex` - DevEx Engineer (laptop config, tooling)

**Privacy**: Personas are generic. Tool names and project details go in `~/AGENTS_LOCAL.md` which stays on your machine only.

### Model Aliases

Personas reference machine-agnostic model aliases (`my/primary`, `my/fast`, `my/planning`). 

Configure these in your machine-specific `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "my": {
      "npm": "@ai-sdk/anthropic",
      "name": "My Models",
      "models": {
        "primary": {
          "id": "claude-sonnet-4-5"
        },
        "fast": {
          "id": "claude-haiku-4-5"
        },
        "planning": {
          "id": "claude-sonnet-4-5"
        }
      }
    }
  }
}
```

This keeps chezmoi files provider-agnostic while allowing per-machine model selection.
