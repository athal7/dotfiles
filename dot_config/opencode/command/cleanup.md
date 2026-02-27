---
description: Clean up old worktrees, databases, and devcontainer resources
---

Clean up stale workspaces, PostgreSQL databases, and Docker resources to reclaim disk space.

`$ARGUMENTS` may include a project name (e.g. `odin`) and/or flags like `--dry-run`, `--force`, `--older-than=N`, `--db-only`, `--docker-only`.

## Step 1: Identify the target project

If a project name is given in `$ARGUMENTS`, find the matching repo path under `~/code/`. Otherwise ask the user which project to clean up before proceeding.

Look up the project in the OpenCode database:

```bash
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id, worktree, sandboxes FROM project WHERE worktree LIKE '%<name>%' ORDER BY time_updated DESC;"
```

If there are **multiple rows for the same worktree path**, that is a duplicate project bug — note all IDs, keep only the newest, delete the rest later.

## Step 2: Discover worktrees

For each sandbox path in the project's `sandboxes` JSON, plus any directories under `~/.local/share/opencode/worktree/<project-id>/`:

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

**IMPORTANT**: Dirty worktrees must NEVER be deleted. Show them clearly and ask the user if they want to keep them before proceeding with anything else.

## Step 4: Present findings and confirm

Show a table before doing anything:

```
=== Worktrees for <project> ===
  SKIP (dirty)   0din-877-brave-planet    1.1G    branch: 0DIN-877-triage-modals    12 uncommitted changes
  SKIP (dirty)   0din-932                 20M     branch: feat/0din-932-heimdall     3 uncommitted changes
  safe           jolly-river              660M    branch: feat/jolly-river           0 sessions, 5 days old
  safe           happy-nebula             157M    branch: feat/happy-nebula          0 sessions, 3 days old
  orphaned       brave-circuit            —       missing from filesystem

=== PostgreSQL databases to drop ===
  jolly-river_odin_development (+ _cable, _cache, _queue)    ~13MB
  happy-nebula_odin_development (+ _cable, _cache, _queue)   ~13MB
  ... (N total databases, ~XGB)

=== OpenCode DB cleanup ===
  Delete stale project row: <id>
  Delete N orphaned sessions for deleted project
  Update sandboxes list
  Update global.dat workspaceOrder + lastProjectSession + globalSync.project
```

Ask: "Delete N safe worktrees and N databases? (dirty ones will be kept)" before proceeding.

## Step 5: Delete safe worktrees

For each safe worktree, use `git worktree remove --force` from the main repo (not rm -rf):

```bash
git -C ~/code/<repo> worktree remove <worktree-path> --force
# If already missing from filesystem, just prune:
git -C ~/code/<repo> worktree prune
```

## Step 6: Drop PostgreSQL databases

For each deleted worktree name, drop all 4 database variants:

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

## Step 7: Clean OpenCode database

Do all of these together:

```bash
# 1. Delete orphaned sessions for any stale project rows
sqlite3 ~/.local/share/opencode/opencode.db \
  "DELETE FROM session WHERE project_id IN ('<stale-id-1>', '<stale-id-2>');"

# 2. Delete stale duplicate project rows (keep newest only)
sqlite3 ~/.local/share/opencode/opencode.db \
  "DELETE FROM project WHERE id IN ('<stale-id-1>', '<stale-id-2>');"

# 3. Update sandboxes list on the good project row to remove deleted paths
sqlite3 ~/.local/share/opencode/opencode.db \
  "UPDATE project SET sandboxes = '<updated-json>' WHERE id = '<good-id>';"
```

## Step 8: Update global.dat

The Desktop app caches project state in `~/Library/Application Support/ai.opencode.desktop/opencode.global.dat`. Must update all three locations while the Desktop app is **closed**:

```python
import json, os

path = os.path.expanduser('~/Library/Application Support/ai.opencode.desktop/opencode.global.dat')
data = json.loads(open(path).read())

# 1. globalSync.project - remove stale project entries
projects = json.loads(data['globalSync.project'])['value']
projects = [p for p in projects if p['id'] not in stale_ids]
data['globalSync.project'] = json.dumps({'value': projects})

# 2. layout.page - fix lastProjectSession and workspaceOrder
layout = json.loads(data['layout.page'])

# Remove lastProjectSession entries pointing to deleted worktrees
for key in list(layout.get('lastProjectSession', {}).keys()):
    entry = layout['lastProjectSession'][key]
    if any(deleted in entry.get('directory', '') for deleted in deleted_worktree_names):
        del layout['lastProjectSession'][key]

# Remove deleted worktrees from workspaceOrder
worktree_path = '/path/to/repo'
if worktree_path in layout.get('workspaceOrder', {}):
    layout['workspaceOrder'][worktree_path] = [
        w for w in layout['workspaceOrder'][worktree_path]
        if not any(d in w for d in deleted_worktree_names)
    ]

data['layout.page'] = json.dumps(layout)
open(path, 'w').write(json.dumps(data))
```

**Ask the user to quit the Desktop app before this step. Verify it's closed before writing.**

After writing global.dat, tell the user to reopen the Desktop app.

## Safety rules (never break these)

1. **Never delete a worktree with uncommitted changes** — show it, warn, skip it
2. **Always delete sessions before deleting project rows** — cascade may not fire
3. **Always update global.dat while Desktop is closed** — open app overwrites changes
4. **Always use `git worktree remove` not `rm -rf`** — keeps git refs clean; use `worktree prune` after for any already-missing ones
5. **Confirm with the user before deleting anything**
