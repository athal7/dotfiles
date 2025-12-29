---
name: worktree-setup
description: Set up git worktrees for concurrent branch development with devcontainers
---

# Git Worktree Setup

Set up a git worktree for working on a separate branch while keeping the main repo intact.

## When to Use

- Working on a PR while main development continues
- Reviewing code that needs a separate environment
- Running multiple branches simultaneously

## Steps

1. **Create the worktree** from the main repo:
   ```bash
   git worktree add ../repo-branch-name branch-name
   ```
   
   For a new branch:
   ```bash
   git worktree add -b new-branch ../repo-new-branch origin/main
   ```

2. **Open in editor**:
   ```bash
   code ../repo-branch-name
   ```

3. **Cleanup** when done:
   ```bash
   git worktree remove ../repo-branch-name
   ```

## With Devcontainers

If the project uses devcontainers, use **local development** for worktrees. Keep devcontainers for the main repo only.

Devcontainers have a [known limitation](https://github.com/devcontainers/cli/issues/796) with worktrees - the `.git` file pointing to the main repo breaks inside containers. The workarounds are fragile and not worth the complexity.
