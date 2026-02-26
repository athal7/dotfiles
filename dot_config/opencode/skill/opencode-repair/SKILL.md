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
# Look for: multiple rows, sandboxes pointing to non-existent paths

# 2. Verify sandbox paths actually exist on disk
ls ~/.local/share/opencode/worktree/<project-id>/

# 3. Check what sessions exist
cd ~/code/<repo> && opencode session list

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

**Fix B: Missing sandbox worktree on disk**

Don't just `mkdir` — must be a real git worktree:

```sh
git -C ~/code/<repo> worktree add \
  ~/.local/share/opencode/worktree/<project-id>/<name> <branch>
```

Then update the DB if the path isn't already in `sandboxes`:

```sh
sqlite3 ~/.local/share/opencode/opencode.db \
  "UPDATE project SET sandboxes = '[\"<worktree-path>\"]' WHERE id = '<project-id>';"
```

**Fix C: Missing from `global.dat`**

```python
import json, os
path = os.path.expanduser(
  '~/Library/Application Support/ai.opencode.desktop/opencode.global.dat'
)
data = json.loads(open(path).read())
layout = json.loads(data['layout.page'])
layout['workspaceOrder']['/path/to/repo'].append('<worktree-path>')
data['layout.page'] = json.dumps(layout)
open(path, 'w').write(json.dumps(data))
```

After any fix: fully quit (Cmd+Q) and reopen Desktop.

**Notes:**
- Duplicate rows accumulate when Desktop creates new project entries instead of reusing existing ones — always check for duplicates first
- `lastProjectSession` pointing to a missing directory causes silent blank render
- `mkdir` is not enough — the worktree must be a real git worktree or Desktop errors on file watching
- Desktop dev tools (`Cmd+Option+I`) are not available in production builds; check logs at `~/Library/Logs/ai.opencode.desktop/`
