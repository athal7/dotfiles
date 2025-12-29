---
name: devcontainer-worktrees
description: Concurrent branch development with devcontainers using clone-based isolation
---

# Devcontainer Worktrees

Strategies for concurrent branch development with full devcontainer isolation.

## The Problem

Git worktrees don't work well with devcontainers. The `.git` file in a worktree contains a host path that breaks inside containers. There's an [open issue](https://github.com/devcontainers/cli/issues/796) but no native fix.

## Recommended: Clone-Based Isolation

Instead of worktrees, clone the repo for each feature branch. This gives you:
- Full devcontainer support (no hacks needed)
- Complete isolation for AI agents
- Standard git behavior
- Independent databases/services per branch

### Create Feature Environment

```bash
# From parent directory of your main repo
git clone myrepo myrepo-feature-x
cd myrepo-feature-x
git checkout -b feature-x

# Open in devcontainer
code .
```

### With Shared Objects (Saves Disk Space)

```bash
# Reference clone shares git objects with main repo
git clone --reference ../myrepo --dissociate repo-url myrepo-feature-x
```

The `--dissociate` flag copies referenced objects, so the clone remains independent if the reference repo is deleted.

### Workflow

```bash
# Work in feature clone
cd myrepo-feature-x
# ... make changes in devcontainer ...
git add . && git commit -m "feat: new feature"
git push origin feature-x

# After PR merges, cleanup
cd ..
rm -rf myrepo-feature-x

# Update main
cd myrepo
git pull
```

## Port Configuration

When running multiple devcontainer instances, configure unique ports to avoid conflicts.

### Update devcontainer.json

```json
{
  "name": "Feature X",
  "forwardPorts": [3010, 5433],
  "portsAttributes": {
    "3010": { "label": "App" },
    "5433": { "label": "Database" }
  }
}
```

### With Docker Compose

```json
{
  "dockerComposeFile": "docker-compose.yml",
  "service": "app",
  "overrideCommand": true
}
```

```yaml
# docker-compose.yml
services:
  app:
    ports:
      - "3010:3000"
  db:
    ports:
      - "5433:5432"
```

### Port Convention

| Instance | App Port | DB Port |
|----------|----------|---------|
| Main     | 3000     | 5432    |
| Feature 1| 3010     | 5433    |
| Feature 2| 3020     | 5434    |

## When to Use Traditional Worktrees

For projects **without** devcontainers, traditional worktrees work fine:

```bash
# Create worktree
git worktree add ../myrepo-feature-x -b feature-x

# Install hooks if needed
cd ../myrepo-feature-x && pre-commit install

# Cleanup when done
git worktree remove ../myrepo-feature-x
```

## Alternative: Git Wrapper Approach

For advanced users who need true worktrees with devcontainers, the [claude-devcontainer](https://github.com/visheshd/claude-devcontainer) project provides a git wrapper that translates paths on the fly. This adds complexity but preserves worktree semantics.

## Summary

| Scenario | Approach |
|----------|----------|
| Devcontainer project, need isolation | Clone-based |
| No devcontainer | Traditional worktrees |
| Need shared refs + devcontainer | Git wrapper (advanced) |
