---
name: worktree-setup
description: Set up git worktrees for concurrent branch development with devcontainers
---

# Git Worktree Setup

Set up a git worktree for working on a separate branch while keeping the main repo intact.

## When to Use

- Working on a PR while main development continues
- Reviewing code that needs a separate environment
- Running multiple branches with devcontainers simultaneously

## Steps

1. **Create the worktree** from the main repo:
   ```bash
   git worktree add ../repo-branch-name branch-name
   ```
   
   For a new branch:
   ```bash
   git worktree add -b new-branch ../repo-new-branch origin/main
   ```

2. **If using devcontainers**, use the `devcontainer-ports` skill to configure unique ports.

3. **Open in VS Code** (will detect devcontainer):
   ```bash
   code ../repo-branch-name
   ```

## Cleanup

When done with the worktree:
```bash
git worktree remove ../repo-branch-name
```

## Notes

- Global gitignore excludes `devcontainer.local.json` so port configs stay local
- `gh-pr-poll` automatically creates worktrees with unique ports for PR reviews
