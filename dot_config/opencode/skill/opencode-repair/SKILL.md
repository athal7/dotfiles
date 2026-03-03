---
name: opencode-repair
description: Fix OpenCode issues - blank sessions, missing worktrees, duplicate project rows, DB repair
---

## Blank Session List for a Project

**Root cause:** Multiple causes are possible. Diagnose in order:

1. **Duplicate project rows** — multiple rows in the `project` table for the same `worktree` path; the web UI may pick a stale row with missing or non-existent sandboxes
2. **Missing sandbox on disk** — a path listed in `sandboxes` no longer exists on disk
3. **Missing from `global.dat`** — paths not in `layout.page` → `workspaceOrder`

**Diagnosis:**

```sh
# 1. Check for duplicate/stale project rows (order by recency)
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id, time_updated, sandboxes FROM project WHERE worktree = '/path/to/repo' ORDER BY time_updated DESC;"
# Look for: multiple rows, sandboxes = [] even though sessions exist

# 2. Verify sandbox paths actually exist on disk
ls ~/.local/share/opencode/worktree/<project-id>/

# 3. Check session directories (NOT sandboxes — sessions use a `directory` column, not sandboxes)
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id, title, directory FROM session WHERE project_id = '<project-id>' ORDER BY time_updated DESC LIMIT 10;"
# directory values are the worktree paths that must exist on disk

# 4. Check global.dat state
python3 -c "
import json, os
d = json.loads(open(os.path.expanduser(
  '~/Library/Application Support/ai.opencode.desktop/opencode.global.dat'
)).read())
layout = json.loads(d['layout.page'])
proj = '/path/to/repo'
print('lastProjectSession:', layout.get('lastProjectSession', {}).get(proj))
print('workspaceOrder:', layout.get('workspaceOrder', {}).get(proj))
"
```

**Common pattern: `sandboxes = []` with sessions present**

The project row has `sandboxes = []` but sessions exist with `directory` pointing to deleted worktrees. This happens when worktrees are pruned/deleted but the DB isn't updated. Symptoms: blank session list despite sessions in DB.

Fix requires three coordinated steps — DB `sandboxes`, disk worktrees, and `global.dat` `workspaceOrder` must all be consistent.

**Fix A: Duplicate stale project rows**

Keep only the most recently updated row; delete the rest:

```sh
# Delete stale rows by ID (keep the newest time_updated)
sqlite3 ~/.local/share/opencode/opencode.db \
  "DELETE FROM project WHERE id IN ('<stale-id-1>', '<stale-id-2>');"

# Verify only one row remains
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id, sandboxes FROM project WHERE worktree = '/path/to/repo';"
```

**Fix B: Missing sandbox worktrees on disk**

Don't just `mkdir` — must be a real git worktree. Recreate all missing ones (check `session.directory` values to find which branches are needed):

```sh
# For each missing worktree path found in session.directory:
git -C ~/code/<repo> worktree add \
  ~/.local/share/opencode/worktree/<project-id>/<name> <branch>
```

Then update the DB `sandboxes` to list all recreated paths (JSON array):

```sh
sqlite3 ~/.local/share/opencode/opencode.db \
  "UPDATE project SET sandboxes = '[\"<path1>\",\"<path2>\"]' WHERE id = '<project-id>';"
```

**Fix C: Update `global.dat` workspaceOrder**

Must be done alongside Fix B — `workspaceOrder` must list the project root plus all sandbox paths:

```python
import json, os
path = os.path.expanduser(
  '~/Library/Application Support/ai.opencode.desktop/opencode.global.dat'
)
data = json.loads(open(path).read())
layout = json.loads(data['layout.page'])
proj = '/path/to/repo'
wt_base = os.path.expanduser('~/.local/share/opencode/worktree/<project-id>')
layout['workspaceOrder'][proj] = [proj, wt_base + '/name1', wt_base + '/name2']
data['layout.page'] = json.dumps(layout)
open(path, 'w').write(json.dumps(data))
```

After any fix: fully quit (Cmd+Q) and reopen Desktop.

**Notes:**
- Duplicate rows accumulate when Desktop creates new project entries instead of reusing existing ones — always check for duplicates first
- `lastProjectSession` pointing to a missing directory causes silent blank render — but clearing it alone is not enough if the underlying worktrees are missing
- `mkdir` is not enough — the worktree must be a real git worktree or Desktop errors on file watching
- Sessions use a `directory` column (not `sandboxes`) — query `session.directory` to find which worktree paths need to exist
- `project.sandboxes` and `global.dat` `workspaceOrder` must be updated together — fixing only one leaves them inconsistent and the UI stays blank
- Desktop dev tools (`Cmd+Option+I`) are not available in production builds; check logs at `~/Library/Logs/ai.opencode.desktop/`
