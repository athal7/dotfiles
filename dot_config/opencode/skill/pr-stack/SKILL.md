---
name: pr-stack
description: Managing stacked/dependent pull requests with GitHub
---

## Tools

**git-spice** (`gs`) is the primary tool for stacked PRs:

```bash
gs repo init                   # Initialize git-spice in a repo
gs branch create <name>        # Create new branch in stack
gs commit create -m "msg"      # Commit with tracking
gs log short                   # List tracked branches (alias: gs ls)
gs log long                    # List branches with commits

# Navigation
gs up / gs down                # Move between stack layers
gs top / gs bottom             # Jump to top/bottom of stack
gs trunk                       # Switch to trunk branch
gs branch checkout <name>      # Switch to a tracked branch
```

**Git aliases** available:
- `git stack-log` — graph of current stack
- `git stack-diff <base>` — diff from merge-base to HEAD
- `git stack-range <base>` — commit range for current layer

## Stack Operations

**Submit** — create/update PRs for the stack:
```bash
gs branch submit               # Submit current branch as PR
gs stack submit                 # Submit all branches in stack
gs downstack submit             # Submit current + below
gs upstack submit               # Submit current + above
```

Navigation comments are auto-synced on downstack PRs (configured via `spice.submit.navigationCommentSync`).

**Sync** — after base branch changes, rebase bottom-up:
```bash
gs repo sync                   # Pull trunk + restack all branches
gs stack restack               # Restack entire stack
gs upstack restack             # Restack current + above
```

**Review one layer** — show only this PR's changes:
```bash
git log <base>..<head> --oneline       # commits
git diff <base>..<head>                # diff
```

**Reorder** — change branch order in a stack:
```bash
gs stack edit                  # Edit full stack order
gs downstack edit              # Edit below current
gs upstack onto <branch>       # Move current branch onto another
```

**Merge** — always bottom-up, rebase dependents after each:
```bash
gh pr merge <pr> --squash --delete-branch
gs repo sync                   # Restacks remaining branches
```

## Manual stack detection

When git-spice isn't initialized:
```bash
gh pr list --json number,title,baseRefName,headRefName,state
```
Chains: PR's `headRefName` equals another PR's `baseRefName`.

## Safety

- Use `--force-with-lease` (never `--force`)
- Confirm before each merge and push (per AGENTS.md safety rules)
- Verify CI passes after each rebase
- Check for conflicts: `gh pr view <pr> --json mergeable`
