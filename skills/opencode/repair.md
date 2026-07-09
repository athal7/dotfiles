## Blank or Stale Session List for a Project

**Root cause:** Multiple causes are possible. Diagnose in order:

1. **Duplicate project rows** — multiple rows in the `project` table for the same `worktree` path; whichever client reads the DB may pick a stale row with missing or non-existent sandboxes
2. **Missing sandbox on disk** — a path listed in `sandboxes` no longer exists on disk

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
```

**Common pattern: `sandboxes = []` with sessions present**

The project row has `sandboxes = []` but sessions exist with `directory` pointing to deleted worktrees. This happens when worktrees are pruned/deleted but the DB isn't updated. Symptoms: a blank or incomplete session/worktree list despite sessions existing in the DB.

**Fix A: Multiple project rows — do NOT delete them**

Multiple rows for the same `worktree` path can occur (e.g. from a historical duplicate insert). Deleting any row breaks the FK constraint on `session`, causing "Failed to create session: FOREIGN KEY constraint failed". Instead, update `sandboxes` on all rows:

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

**Notes:**
- Never DELETE project rows, only UPDATE sandboxes
- `mkdir` is not enough — the worktree must be a real git worktree or file-watching errors on it
- Sessions use a `directory` column (not `sandboxes`) — query `session.directory` to find which worktree paths need to exist

## OpenCode Binary Architecture

Distinct `opencode` binaries can coexist on a machine — they are NOT interchangeable:

| Binary | Type | Standalone? |
|--------|------|-------------|
| GitHub-release native (`~/.local/bin/opencode`, chezmoi-managed) | Mach-O Bun binary | Yes — this is the canonical binary for aoe-hosted sessions and editor integrations |
| Brew native (`/opt/homebrew/opt/opencode/.../opencode-darwin-arm64/bin/opencode`) | Mach-O Bun binary | Yes |
| Brew wrapper (`/opt/homebrew/bin/opencode`) | Node.js script | Broken — walks `node_modules` from `bin/` dir, never finds native binary in `libexec/` |

**Key facts:**
- The brew wrapper checks `OPENCODE_BIN_PATH` env var first — set this to bypass the broken `node_modules` walk
- The curl-install-script binary (`~/.opencode/bin/opencode`, a different path than the chezmoi github-release binary) is a self-contained Bun binary, self-updating via `opencode upgrade` — but has been observed to crash with SIGKILL in some contexts; prefer the github-release binary
- Brew `opencode` formula has no `service` stanza — `brew services` cannot manage it
- Any script or LaunchAgent invoking `opencode` directly should point at a native Mach-O binary (github-release or brew native) — never the Node wrapper
- Stable brew native binary path: `/opt/homebrew/opt/opencode/libexec/lib/node_modules/opencode-ai/node_modules/opencode-darwin-arm64/bin/opencode` (the `opt` symlink survives upgrades, but `darwin-arm64` is arch-specific)

## LaunchAgent Reload

`launchctl unload`/`load` can leave stale PIDs. Use `bootout`/`bootstrap` for clean restarts:
```sh
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/<plist>
sleep 1
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<plist>
```
