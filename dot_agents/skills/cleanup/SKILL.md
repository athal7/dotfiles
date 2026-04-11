---
name: cleanup
description: Reclaim disk space by removing stale git worktrees, dropping PostgreSQL databases, and updating the OpenCode DB and global.dat to remove deleted workspace entries
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
---

Clean up stale workspaces, PostgreSQL databases, and Docker resources to reclaim disk space.

Arguments may include a project name (e.g. `odin`) and/or flags like `--dry-run`, `--force`, `--older-than=N`, `--db-only`, `--docker-only`.

## Step 1: Identify the target project

If a project name is given, find the matching repo path under `~/code/`. Otherwise ask the user which project to clean up before proceeding.

Find the project's worktree directory ID:

```bash
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id, worktree, sandboxes FROM project WHERE worktree LIKE '%<name>%' LIMIT 1;"
```

Use the `id` from this row to locate worktrees at `~/.local/share/opencode/worktree/<id>/`.

## Step 2: Discover worktrees

```bash
for dir in ~/.local/share/opencode/worktree/<project-id>/*/; do
  name=$(basename "$dir")
  branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "unknown")
  changes=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  size=$(du -sh "$dir" 2>/dev/null | cut -f1)
  last=$(stat -f '%Sa' -t '%Y-%m-%d' "$dir" 2>/dev/null)
  sessions=$(sqlite3 ~/.local/share/opencode/opencode.db \
    "SELECT COUNT(*) FROM session WHERE directory = '$dir';")
  echo "$name | $branch | changes=$changes | sessions=$sessions | $size | $last"
done
```

## Step 3: Classify each worktree

| Status | Criteria |
|--------|----------|
| **SKIP - dirty** | Has uncommitted changes (`changes > 0`) — **never delete, warn user** |
| **SKIP - active** | Accessed within `--older-than` days (default 7) AND has sessions |
| **Safe to delete** | No uncommitted changes, no recent sessions |
| **Orphaned** | Directory missing from filesystem but still in DB sandboxes |

**IMPORTANT**: Dirty worktrees must NEVER be deleted. Show them clearly before proceeding.

## Step 4: Present findings and confirm

```
=== Worktrees for <project> ===
  SKIP (dirty)   brave-planet    1.1G    branch: feat/brave-planet    12 uncommitted changes
  safe           jolly-river     660M    branch: feat/jolly-river      0 sessions, 5 days old
  orphaned       brave-circuit   —       missing from filesystem

=== PostgreSQL databases to drop ===
  jolly-river_<app>_development (+ _cable, _cache, _queue)    ~13MB
  ... (N total databases, ~XGB)

=== OpenCode DB cleanup ===
  Update sandboxes list (remove deleted paths)
  Update global.dat workspaceOrder + lastProjectSession
```

Ask: "Delete N safe worktrees and N databases? (dirty ones will be kept)" before proceeding.

## Step 5: Delete safe worktrees

```bash
git -C ~/code/<repo> worktree remove <worktree-path> --force
# If already missing from filesystem, just prune:
git -C ~/code/<repo> worktree prune
```

Orphaned tmp-only dirs (not registered git worktrees — contain only a `tmp/` subdir) can be `rm -rf`'d directly.

## Step 6: Drop PostgreSQL databases

```bash
for name in <deleted-worktree-names>; do
  for suffix in "" "_cable" "_cache" "_queue"; do
    psql -U postgres -c "DROP DATABASE IF EXISTS \"${name}_<app>_development${suffix}\";" 2>/dev/null
  done
done
```

**Never drop**:
- The base `<app>_development` database (no worktree prefix)
- `<app>_test*` databases
- Databases for worktrees that still exist

## Step 7: Update OpenCode database sandboxes

Update `sandboxes` on **all** project rows for this repo to remove the deleted paths (multiple rows are normal — web service and Desktop each have one, never delete them):

```bash
sqlite3 ~/.local/share/opencode/opencode.db \
  "UPDATE project SET sandboxes = '<updated-json>' WHERE worktree = '/path/to/repo';"
```

## Step 8: Update global.dat

Must be done while the Desktop app is **closed**. Ask the user to quit it (Cmd+Q) and verify before writing.

```python
import json, os

path = os.path.expanduser('~/Library/Application Support/ai.opencode.desktop/opencode.global.dat')
data = json.loads(open(path).read())
layout = json.loads(data['layout.page'])

# Remove lastProjectSession entries pointing to deleted worktrees
for key in list(layout.get('lastProjectSession', {}).keys()):
    entry = layout['lastProjectSession'][key]
    directory = entry.get('directory', '') if isinstance(entry, dict) else str(entry)
    if any(d in directory for d in deleted_worktree_names):
        del layout['lastProjectSession'][key]

# Purge deleted worktrees from workspaceOrder (filter to paths that exist on disk)
for proj_path, workspaces in layout.get('workspaceOrder', {}).items():
    layout['workspaceOrder'][proj_path] = [w for w in workspaces if os.path.exists(w)]

data['layout.page'] = json.dumps(layout)
open(path, 'w').write(json.dumps(data))
```

After writing, tell the user to reopen the Desktop app.

## Safety rules

1. **Never delete a worktree with uncommitted changes**
2. **Never DELETE project rows** — breaks FK constraints on `session`, causing "Failed to create session" errors; only UPDATE sandboxes
3. **Always update global.dat while Desktop is closed** — open app overwrites changes
4. **Always use `git worktree remove` not `rm -rf`** for registered git worktrees
5. **Confirm with the user before deleting anything**
