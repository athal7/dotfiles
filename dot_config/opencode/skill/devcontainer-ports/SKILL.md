---
name: devcontainer-ports
description: Configure unique ports for running multiple devcontainer instances simultaneously
---

# Devcontainer Port Configuration

Configure unique ports when running multiple devcontainer instances (e.g., multiple repos open simultaneously).

## When to Use

- Running multiple devcontainer projects at once
- Port conflicts between containers

## Port Assignment

Update `devcontainer.json` with unique ports per project:

```json
{
  "name": "Project Name",
  "runArgs": ["-p", "3010:3000"],
  "forwardPorts": [3010]
}
```

## Port Convention

| Project/Instance | Host Port |
|------------------|-----------|
| Primary project  | 3000      |
| Secondary        | 3010      |
| Third            | 3020      |

## Worktrees

Don't use devcontainers with git worktrees. There's a [known limitation](https://github.com/devcontainers/cli/issues/796) where the `.git` file breaks inside containers. Use local development for worktrees instead.
