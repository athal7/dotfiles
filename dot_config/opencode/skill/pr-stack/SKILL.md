---
name: pr-stack
description: Managing stacked/dependent pull requests with GitHub
---

## Tools

**git-spice** (`gs`) is the primary tool for stacked PRs:

```bash
gs stack tree              # Visualize stack structure
gs stack sync              # Rebase entire stack after base changes
gs stack submit            # Create/update all PRs in stack
gs branch create <name>    # Create new layer in stack
gs upstack restack         # Rebase branches above current
gs ls                      # List all tracked branches
```

**Git aliases** available:
- `git stack-log` — graph of current stack
- `git stack-diff <base>` — diff from merge-base to HEAD
- `git stack-range <base>` — commit range for current layer

**Manual stack detection** (when git-spice isn't initialized):
```bash
gh pr list --json number,title,baseRefName,headRefName,state
```
Chains: PR's `headRefName` equals another PR's `baseRefName`.

## Stack Operations

**Sync** — after base branch changes, rebase bottom-up:
```bash
gs stack sync                          # preferred
# or manually:
git rebase origin/<base-branch>
git push --force-with-lease
```

**Review one layer** — show only this PR's changes:
```bash
git log <base>..<head> --oneline       # commits
git diff <base>..<head>                # diff
```

**Merge** — always bottom-up, rebase dependents after each:
```bash
gh pr merge <pr> --squash --delete-branch
gh pr edit <dependent-pr> --base main  # retarget after merge
```

## PR Body Template

```markdown
## Summary
[Changes in this layer]

## Dependencies
- Based on #<parent-pr> (`<parent-branch>`)

## Review Notes
View only this PR's changes:
`git diff <parent-branch>..<this-branch>`
```

## Safety

- Use `--force-with-lease` (never `--force`)
- Confirm before each merge and push (per AGENTS.md safety rules)
- Verify CI passes after each rebase
- Check for conflicts: `gh pr view <pr> --json mergeable`
