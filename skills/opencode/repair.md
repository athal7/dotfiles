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

**Fix A: Multiple project rows — do NOT delete them**

Multiple rows for the same `worktree` path is **expected** — the web service and Desktop app each maintain their own row. Deleting any row breaks the FK constraint on `session`, causing "Failed to create session: FOREIGN KEY constraint failed". Instead, update `sandboxes` on all rows:

```sh
# Update sandboxes on ALL rows for this worktree
sqlite3 ~/.local/share/opencode/opencode.db \
  "UPDATE project SET sandboxes = '[\"<path1>\",\"<path2>\"]' WHERE worktree = '/path/to/repo';"
```

**Recovery if you accidentally deleted a project row** (FK errors on session create):

```sh
# Re-insert the deleted row — get time values from another project row for reference
NOW=$(date +%s)000
sqlite3 ~/.local/share/opencode/opencode.db \
  "INSERT INTO project (id, worktree, vcs, sandboxes, time_created, time_updated) \
   VALUES ('<deleted-id>', '/path/to/repo', 'git', '[]', $NOW, $NOW);"
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
- Multiple rows per repo is normal (web + Desktop each own one) — never DELETE project rows, only UPDATE sandboxes
- `lastProjectSession` pointing to a missing directory causes silent blank render — but clearing it alone is not enough if the underlying worktrees are missing
- `mkdir` is not enough — the worktree must be a real git worktree or Desktop errors on file watching
- Sessions use a `directory` column (not `sandboxes`) — query `session.directory` to find which worktree paths need to exist
- `project.sandboxes` and `global.dat` `workspaceOrder` must be updated together — fixing only one leaves them inconsistent and the UI stays blank
- Desktop dev tools (`Cmd+Option+I`) are not available in production builds; check logs at `~/Library/Logs/ai.opencode.desktop/`

## Stale Workspace File-Picker Errors

**Symptom:** `opencode-web` logs repeated `Failed to init file picker: Invalid path /Users/athal/.local/share/opencode/worktree/<project-id>/<name>` — one per pruned/deleted worktree. Often only the most-recently-touched one or two surface, but every dead entry is a latent error.

**Root cause:** The web serve process initializes a file picker for every workspace it has metadata for in `global.dat`. Worktrees get pruned from disk, but the `workspaceName` / `workspaceBranchName` metadata in `global.dat` is not cleaned up, leaving orphaned entries that point at non-existent paths.

**Key state-file facts:**

- File: `~/Library/Application Support/ai.opencode.desktop/opencode.global.dat` (JSON; the Desktop Electron app's storage, shared with the web serve process). NOT chezmoi-managed (runtime state).
- Keys use a **NUL byte** (`chr(0)`) separator. The web service's layout key is literally `'http://localhost:4096' + chr(0) + 'layout.page'`. The Desktop app's own key is just `'layout.page'`. Using a space instead of `chr(0)` returns nothing.
- Both layout values are stored as **JSON strings**, not nested objects — round-trip with `json.loads` → edit → `json.dumps`.
- `workspaceName`: dict keyed by **absolute worktree path** → display value (e.g. `'opencode/silent-orchid'`). The dead entries live here.
- `workspaceBranchName`: dict keyed by **project-id** → `{ displayValue → branchName }`.
- `workspaceOrder` and `lastProjectSession` are keyed by project root path and usually stay clean — the dead entries are name/branch metadata only.

**Fix:** Quit Desktop first (Cmd+Q) so it doesn't clobber the edit, back up the file, then prune every `workspaceName` entry whose worktree path no longer exists on disk (and the matching `workspaceBranchName[project-id][displayValue]`), for BOTH the web key and the Desktop `layout.page` key. Keep entries whose worktree path still exists.

```python
import json, os, time

path = os.path.expanduser(
  '~/Library/Application Support/ai.opencode.desktop/opencode.global.dat'
)
data = json.loads(open(path).read())
open(path + '.bak.' + str(int(time.time())), 'w').write(json.dumps(data))

web_key = 'http://localhost:4096' + chr(0) + 'layout.page'
for key in ('layout.page', web_key):
    if key not in data:
        continue
    layout = json.loads(data[key])
    names = layout.get('workspaceName', {})
    branches = layout.get('workspaceBranchName', {})
    for p in [p for p in names if not os.path.isdir(p)]:
        display = names.pop(p)
        projid = p.split('/worktree/')[1].split('/')[0]
        if projid in branches:
            branches[projid].pop(display, None)
    data[key] = json.dumps(layout)

open(path, 'w').write(json.dumps(data))
```

Then reopen Desktop (`open -a OpenCode`). **Do NOT restart `opencode-web`** — it may host live mobile/automated-job sessions and reads `workspaceName` on demand, so the pruned file takes effect without a restart.

---

## OpenCode Binary Architecture

Three distinct `opencode` binaries exist — they are NOT interchangeable:

| Binary | Type | Standalone? | TUI? | Web? |
|--------|------|-------------|------|------|
| Brew native (`/opt/homebrew/opt/opencode/.../opencode-darwin-arm64/bin/opencode`) | Mach-O Bun binary | Yes | Yes | Yes |
| Brew wrapper (`/opt/homebrew/bin/opencode`) | Node.js script | Broken — walks `node_modules` from `bin/` dir, never finds native binary in `libexec/` | No | No |
| Desktop CLI (`/Applications/OpenCode.app/Contents/MacOS/opencode-cli`) | Mach-O Electron IPC | No — requires Desktop app running, exits silently with code 0 if app not running | No | No |

**Key facts:**
- The brew wrapper checks `OPENCODE_BIN_PATH` env var first — set this to bypass the broken `node_modules` walk
- The install-script binary (`~/.opencode/bin/opencode`) is a self-contained Bun binary, self-updating via `opencode upgrade`
- Brew `opencode` formula has no `service` stanza — `brew services` cannot manage it
- The web service plist must point directly at the native Mach-O binary, not the Node wrapper or Desktop CLI
- Stable brew native binary path: `/opt/homebrew/opt/opencode/libexec/lib/node_modules/opencode-ai/node_modules/opencode-darwin-arm64/bin/opencode` (the `opt` symlink survives upgrades, but `darwin-arm64` is arch-specific)

## Web UI Frontend Asset Bug Diagnosis

When the web UI crashes with `e.text.length` (undefined is not an object):
1. Check the asset hashes in the error URL (e.g., `session-BBe8m5zc.js`)
2. Compare with `curl -s http://localhost:<port> | grep -o 'session-[^"]*\.js'` — if hashes match after upgrade, the web bundle wasn't rebuilt
3. The `part` table has types `text`, `tool`, `step-start`, `step-finish`, `reasoning`, `agent`, `compaction`, `patch`, `file`, `subtask` — the UI may crash on newer types that lack a `.text` field
4. DB data being clean (no null `.text` on text parts) means the bug is in the frontend renderer, not corrupted data — don't waste time investigating the DB

## LaunchAgent Reload

`launchctl unload`/`load` can leave stale PIDs. Use `bootout`/`bootstrap` for clean restarts:
```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/<plist>
sleep 1
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<plist>
```
