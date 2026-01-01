---
name: worktrees
description: Concurrent branch development using git worktrees or devcontainer clones
---

# Worktrees

Strategies for working on multiple branches simultaneously.

## Decision: Worktrees vs Clones

| Project type | Approach |
|--------------|----------|
| No devcontainer | Git worktrees |
| Has devcontainer | Clones via `ocdc up` |

Git worktrees don't work inside devcontainers because the `.git` file references a path outside the mounted directory.

## Git Worktrees (No Devcontainer)

```bash
# Create worktree for a branch
git worktree add ../myapp-feature-x feature-x

# List worktrees
git worktree list

# Remove when done
git worktree remove ../myapp-feature-x
```

Worktrees share the same `.git` directory, so commits in one are immediately visible in others.

## Devcontainer Clones (ocdc)

Use `ocdc` for automatic port assignment and clone management:

```bash
# Start devcontainer for current branch
cd ~/Projects/myapp
ocdc up                 # Starts on port 13000

# Start devcontainer for a feature branch (creates clone automatically)
ocdc up feature-x       # Starts on port 13001

# Interactive TUI for managing all instances
ocdc                    # No args launches TUI

# List all running instances
ocdc list

# Execute commands in container
ocdc exec bash
ocdc exec bin/rails console

# Navigate to existing clone
ocdc go feature-x       # Opens VS Code in VS Code terminal, prints cd otherwise

# Stop instances
ocdc down               # Stop current
ocdc down --all         # Stop all
ocdc down --prune       # Clean up stale entries
ocdc down --remove-clone # Stop and delete clone
```

### How It Works

1. **Auto-port assignment**: Ports assigned from 13000-13099, tracked in `~/.cache/ocdc/ports.json`
2. **Override config**: Creates ephemeral override files using `--override-config` flag - repo's devcontainer.json is never modified
3. **Clones**: Stored in `~/.cache/devcontainer-clones/<repo>/<branch>/` (uses `--reference --dissociate` to save space)
4. **Isolation**: Each instance gets its own port and database

### Configuration

Create `~/.config/ocdc/config.json` to customize:

```json
{
  "portRangeStart": 13000,
  "portRangeEnd": 13099
}
```

### Installation

```bash
brew install athal7/tap/ocdc
```

## Cleanup

After merging a branch:

- **Worktrees**: `git worktree remove <path>`
- **Devcontainer clones**: `ocdc down --remove-clone` or `rm -rf ~/.cache/devcontainer-clones/<repo>/<branch>`
