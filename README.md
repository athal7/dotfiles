## athal7's dotfiles

Using [chezmoi](https://chezmoi.io) for dotfile management.

## Setup

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply athal7
```

Then fill in machine-specific details:
- `~/.env` - environment variables and API keys (loaded by direnv)
- `~/.config/opencode/opencode.json` - model configuration (merged with chezmoi-managed MCP settings)
- `~/.config/opencode/AGENTS.local.md` - machine-specific context (auto-discovered)

Automatic setup includes:
- Homebrew packages via Brewfile (including `opencode` and `opencode-desktop`)

## OpenCode Configuration

See [AGENTS.md](AGENTS.md) for structure and conventions when editing this repo.

Global agent instructions deploy to `~/.config/opencode/AGENTS.md` and auto-generate lists of:
- CLI tools (from Brewfile comments)
- Subagents (from `agent/*.md` with `mode: subagent`)
- Local agents (from `agent/*.md` with `model: ollama/*`)
- Commands (from `command/*.md`)
