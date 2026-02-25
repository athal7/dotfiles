---
name: opencode-desktop
description: Fix OpenCode Desktop issues - blank sessions, missing worktrees, DB repair
---

## Blank Session List for a Project

**Root cause:** Two things must both be true for Desktop to render sessions:
1. The `sandboxes` field in the `project` DB table must contain the worktree paths
2. Those paths must appear in `layout.page` → `workspaceOrder` in `opencode.global.dat`

If either is missing, Desktop silently shows a blank session list.

**Diagnosis:**

```sh
# Find project ID
sqlite3 ~/.local/share/opencode/opencode.db \
  "SELECT id, sandboxes FROM project WHERE worktree = '/Users/athal/code/<repo>';"
# Pick the row with sandboxes and commands populated (not empty legacy rows)

# Check what sessions exist
cd ~/code/<repo> && opencode session list

# Check last-opened session path
python3 -c "
import json, os
d = json.loads(open(os.path.expanduser(
  '~/Library/Application Support/ai.opencode.desktop/opencode.global.dat'
)).read())
layout = json.loads(d['layout.page'])
print(layout['lastProjectSession'].get('/Users/athal/code/<repo>'))
print(layout['workspaceOrder'].get('/Users/athal/code/<repo>'))
"
```

**Fix:**

1. Create the missing git worktree (don't just `mkdir` — must be a real git worktree):
   ```sh
   git -C ~/code/<repo> worktree add \
     ~/.local/share/opencode/worktree/<project-id>/<name> <branch>
   ```

2. Add it to `sandboxes` in the DB:
   ```sh
   sqlite3 ~/.local/share/opencode/opencode.db \
     "UPDATE project SET sandboxes = '[\"<worktree-path>\"]' WHERE id = '<project-id>';"
   ```

3. Add it to `workspaceOrder` in `opencode.global.dat`:
   ```python
   import json, os
   path = os.path.expanduser(
     '~/Library/Application Support/ai.opencode.desktop/opencode.global.dat'
   )
   data = json.loads(open(path).read())
   layout = json.loads(data['layout.page'])
   layout['workspaceOrder']['/Users/athal/code/<repo>'].append('<worktree-path>')
   data['layout.page'] = json.dumps(layout)
   open(path, 'w').write(json.dumps(data))
   ```

4. Fully quit (Cmd+Q) and reopen Desktop.

**Notes:**
- `lastProjectSession` pointing to a missing directory causes silent blank render
- `mkdir` is not enough — the worktree must be a real git worktree or Desktop errors on file watching
- The DB and `global.dat` must both be updated; fixing only one is not sufficient
- Desktop dev tools (`Cmd+Option+I`) are not available in production builds; check logs at `~/Library/Logs/ai.opencode.desktop/`
