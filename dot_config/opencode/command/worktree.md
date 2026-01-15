---
description: Create a git worktree for isolated branch work
---

Create a git worktree in the standard location for concurrent branch development.

**Arguments:** $ARGUMENTS

## Usage

```
/worktree <branch-name>        # Create new branch and worktree
/worktree -b <branch-name>     # Same as above (explicit)
/worktree <existing-branch>    # Create worktree for existing branch
```

## Process

1. **Validate** - Ensure we're in a git repo (not already in a worktree)
2. **Parse arguments** - Extract branch name from `$ARGUMENTS`
3. **Create worktree** - Using standard location:
   ```bash
   git worktree add ~/.local/share/opencode/worktree/$(basename $PWD)/<branch> -b <branch>
   ```
   Or for existing branch:
   ```bash
   git worktree add ~/.local/share/opencode/worktree/$(basename $PWD)/<branch> <branch>
   ```
4. **Copy ignored secrets** - Copy gitignored secrets from main repo:
   ```bash
   # Find gitignored files that exist in main repo
   git ls-files --ignored --exclude-standard -c | while read f; do
     [ -f "$f" ] && cp "$f" "<worktree_path>/$f"
   done
   # Common examples: config/master.key, .env.local, credentials files
   ```
5. **Setup environment** - Run `direnv allow` in the new worktree
6. **Run setup** - If `bin/setup` exists, run it (handles db creation, dependencies)
7. **Report** - Show the path, port, and database info

## Port & Database Isolation

Projects using worktrees should have an `.envrc` that:
- Sets `PORT` based on worktree name (deterministic hash to avoid conflicts)
- Sets `DATABASE_PREFIX` for isolated databases

Example pattern (projects can copy this to `.envrc`):
```bash
export WORKTREE_NAME=$(basename $PWD)
if [[ "$WORKTREE_NAME" == "main" || "$WORKTREE_NAME" == "<repo>" ]]; then
  export PORT=3000
else
  export PORT=$((3000 + $(echo -n "$WORKTREE_NAME" | cksum | cut -d' ' -f1) % 100 + 1))
fi
export DATABASE_PREFIX="${WORKTREE_NAME}_"
```

## Output

Report:
- Full path to the new worktree
- Branch name
- Port (from `source .envrc && echo $PORT`)
- Database prefix if set
- Next steps: "cd <path> or open new terminal there"

## Standard Location

All worktrees go to: `~/.local/share/opencode/worktree/<repo>/<branch>/`

This ensures:
- Consistent location across all repos
- Easy cleanup via `/cleanup`
- Isolation from main working directory
- `~/.env` secrets loaded via global direnv config

## Errors

- If already in a worktree, suggest using the main repo instead
- If branch already exists and user didn't specify, ask whether to use existing or create new
- If worktree already exists at that path, report the existing path
