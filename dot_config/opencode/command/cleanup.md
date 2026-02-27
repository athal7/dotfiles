---
description: Clean up old worktrees, databases, and devcontainer resources
---

Clean up stale workspaces, PostgreSQL databases, and Docker resources to reclaim disk space.

## Supported Cleanup

This command handles:
- **Worktrees**: Orphaned or old git worktrees in `~/.local/share/opencode/worktree/`
- **Databases**: PostgreSQL development databases for deleted worktrees
- **Snapshots**: Old OpenCode snapshots and session data
- **Devcontainers**: Stopped containers and dangling Docker resources

## Quick Start

```bash
# Dry-run to see what would be deleted
/cleanup --dry-run

# Delete all safe items (old, no uncommitted changes)
/cleanup --force

# Delete specific project
/cleanup odin

# Older than N days (default: 7)
/cleanup --older-than=14
```

## Discovery & Analysis

The command will:

1. **Scan worktrees** - Find all worktrees with access time and changes status
2. **Identify databases** - List PostgreSQL databases for each worktree prefix
3. **Check Docker** - Find containers and images associated with deleted worktrees
4. **Calculate savings** - Show total disk space and database size

## Database Cleanup

For PostgreSQL, the cleanup identifies and removes:
- Development databases matching deleted worktree names
- Suffix variants: `_cable`, `_cache`, `_queue`
- Test databases from abandoned sessions (with TTL)

**Kept by default**:
- `odin_development` (base development)
- `odin_test*` (active test suite)
- Databases for existing worktrees

## Output Format

```
=== Worktrees (3.5GB total) ===
[ ] 0din-877-brave-planet      1.1G    2 days ago    Safe to delete
[!] jolly-river                660M    5 hours ago   Active - skip
[-] hidden-cabin               16K     30 days ago   Orphaned

=== Databases (2.3GB total) ===
DROP: 181 development DBs        1.2GB    Odin worktrees
KEEP: odin_development (base)    14MB
KEEP: 16 test databases          224MB

=== Docker Resources ===
Remove: 4 stopped containers     128MB
Remove: 8 dangling images        512MB
Remove: 2 dangling volumes       256MB
```

## Safety Features

✓ **Uncommitted changes** - Warns before deletion
✓ **Access time** - Won't delete recently accessed
✓ **Running containers** - Won't delete active workspaces
✓ **Dry-run mode** - See changes before applying
✓ **Confirmation** - Prompts for each deletion

## Arguments

- `--dry-run` - Preview changes without executing
- `--force` - Skip confirmations for safe deletions
- `--older-than=N` - Only consider items unused for N+ days (default: 7)
- `PROJECT` - Target specific project (e.g., `odin`, `garak`)
- `--db-only` - Clean databases only
- `--docker-only` - Clean Docker resources only
