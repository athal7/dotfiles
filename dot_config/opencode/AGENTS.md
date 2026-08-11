# Agent Instructions

## Host-Specific Files (NOT managed by chezmoi)

- `~/.config/zsh/private.zsh` — work-specific shell config (sourced at end of `.zshrc`)
- `~/.config/agentskills/private-install.sh` — host-local private agent-skill installs (gh skill install lines for private repos), run by the skill-sync script

## Cross-Repo Work

Never edit files or run commands directly in a repository other than the one this session was opened in. Dispatch an `aoe` session for it instead (see the aoe skill).
