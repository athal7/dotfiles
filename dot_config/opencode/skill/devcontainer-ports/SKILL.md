---
name: devcontainer-ports
description: Configure unique ports for running multiple devcontainer instances simultaneously
---

# Devcontainer Port Configuration

Configure unique ports for devcontainers to run multiple instances simultaneously.

## When to Use

- Running multiple worktrees with devcontainers
- Port conflicts between devcontainer instances
- Setting up a new worktree for PR review

## Ports to Avoid

Common ports likely already in use:
- **x001-x005** (e.g., 3001-3005, 4001-4005) - often used by local services
- **3000** - Rails, Node, React
- **5000** - Flask, .NET
- **5432** - Postgres
- **6379** - Redis
- **8080** - various web servers

## Find an Available Port

```bash
# Check ports already assigned in sibling worktrees
grep -rh '"runArgs"' ../*/.devcontainer/devcontainer.local.json 2>/dev/null

# Find a port not in use (empty output = available)
lsof -i :PORT -sTCP:LISTEN
```

## Create the Override File

Create `.devcontainer/devcontainer.local.json` in the worktree:

```json
{
  "name": "ProjectName - branch-name",
  "runArgs": ["-p", "HOST_PORT:CONTAINER_PORT"],
  "forwardPorts": [HOST_PORT]
}
```

Replace `HOST_PORT` with an available port and `CONTAINER_PORT` with the port the app listens on inside the container.

## How It Works

- VS Code merges `devcontainer.local.json` with `devcontainer.json`
- Global gitignore excludes `devcontainer.local.json` so it's never committed

## Troubleshooting

**Port in use**: `lsof -i :PORT -sTCP:LISTEN` then `kill -9 <PID>`

**Container not picking up port**: Rebuild container in VS Code (Cmd+Shift+P → "Dev Containers: Rebuild Container")
