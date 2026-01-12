---
description: Clean up old opencode worktrees and devcontainer clones
---

Clean up stale workspaces and associated Docker resources to reclaim disk space.

## Locations

- **Git worktrees**: `~/.local/share/opencode/worktree/`
- **Devcontainer clones**: `~/.local/share/opencode/clone/`

## Discovery

Gather information about what exists:

```bash
# List all worktree directories with last access time
find ~/.local/share/opencode/worktree -mindepth 2 -maxdepth 2 -type d 2>/dev/null | while read dir; do
  echo "$(stat -f '%Sa' -t '%Y-%m-%d' "$dir") $dir"
done | sort

# List all clone directories with last access time  
find ~/.local/share/opencode/clone -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read dir; do
  echo "$(stat -f '%Sa' -t '%Y-%m-%d' "$dir") $dir"
done | sort

# Identify parent repos for each worktree hash
for hash_dir in ~/.local/share/opencode/worktree/*/; do
  hash=$(basename "$hash_dir")
  worktree=$(find "$hash_dir" -mindepth 1 -maxdepth 1 -type d | head -1)
  if [ -n "$worktree" ] && [ -f "$worktree/.git" ]; then
    main_worktree=$(cat "$worktree/.git" | grep gitdir | sed 's/gitdir: //' | sed 's|/\.git/worktrees/.*||')
    echo "$hash -> $main_worktree"
  fi
done

# Get branch, uncommitted changes, and size for each worktree
for dir in ~/.local/share/opencode/worktree/*/*/; do
  [ -d "$dir/.git" ] || [ -f "$dir/.git" ] || continue
  branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "unknown")
  changes=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  size=$(du -sh "$dir" 2>/dev/null | cut -f1)
  echo "$dir|$branch|$changes|$size"
done
```

## Docker Discovery

```bash
# Check all devcontainers (running and stopped)
docker ps -a --filter "label=devcontainer.local_folder" \
  --format "table {{.ID}}\t{{.Status}}\t{{.Label \"devcontainer.local_folder\"}}"

# Check devcontainer images (vsc-* pattern)
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}" \
  | grep -E "vsc-|devcontainer"

# Check dangling volumes
docker volume ls -f dangling=true

# Check disk usage summary
docker system df
```

## Analysis

For each workspace, check:

1. **Last access time** - Flag anything not accessed in 7+ days
2. **Uncommitted changes** - Warn if there's uncommitted work
3. **Running containers** - Check if devcontainer is still running
4. **Associated Docker resources** - Images, stopped containers, volumes

## Output

Present findings in tables:

### Workspaces
| Location | Repo | Branch | Last Access | Size | Status |
|----------|------|--------|-------------|------|--------|

Status should be:
- **Safe to delete** - No uncommitted changes, old
- **Has uncommitted work** - Warn before deletion
- **Active** - Recently accessed or running container
- **Orphaned** - Worktree reference broken

### Docker Resources
| Type | ID/Name | Associated Workspace | Size | Status |
|------|---------|---------------------|------|--------|

## Cleanup

After showing the tables, ask which to clean up. Offer options:
- "Delete all safe items?"
- "Select specific items?"  
- "Skip for now?"

### Worktree Deletion

**Important**: Must run `git worktree remove` from the **main repo**, not the worktree directory.

```bash
# Find the main repo for a worktree
main_repo=$(cat <worktree_path>/.git | grep gitdir | sed 's/gitdir: //' | sed 's|/\.git/worktrees/.*||')

# Remove the worktree from the main repo
git -C "$main_repo" worktree remove <worktree_path> --force

# Prune any orphaned worktree references
git -C "$main_repo" worktree prune

# For completely orphaned directories (no .git reference)
rm -rf <orphaned_path>
```

### Docker Cleanup

Clean up in this order to release dependencies:

```bash
# 1. Stop running containers associated with deleted workspaces
docker stop <container_id>

# 2. Remove stopped containers (releases volume references)
docker rm <container_id>

# 3. Remove devcontainer images for deleted workspaces (vsc-<workspace-name>-*)
docker rmi <image_name>

# 4. Remove dangling volumes (must remove containers first!)
# Note: `docker volume prune -f` may not work; use explicit removal:
docker volume rm $(docker volume ls -q -f dangling=true)

# 5. Prune unused images (removes base images if not in use)
docker image prune -a -f

# 6. Clear build cache
docker builder prune -f
```

**Important**: Volumes won't be pruned while containers (even stopped ones) reference them. Always remove containers before pruning volumes.

### Clone Deletion

```bash
# For devcontainer clones - stop and remove container first
docker stop <container_id> && docker rm <container_id>
rm -rf <clone_path>
```

## Arguments

- `$ARGUMENTS` can include:
  - `--dry-run` - Show what would be deleted without deleting
  - `--older-than=N` - Only show items older than N days (default: 7)
  - `--force` - Skip confirmation for safe-to-delete items
