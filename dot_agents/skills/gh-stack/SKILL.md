---
name: gh-stack
description: Load when deciding whether to use gh stack or working on dependent, stacked GitHub pull requests
license: MIT
---

## Choose the path

- Fetch any named PR first. Inspect its base, head, and downstack PRs with the official GitHub MCP; a branch name or installed extension alone does not establish a stack.
- One independent PR: use the normal GitHub MCP workflow, not `gh stack`. This dotfiles repository deploys without PRs.
- Two or more dependent PRs (or a stack the user asked to manage): use stack-aware operations for branch order, remote stack linking, and atomic stack merge. Existing PR base chains need not be adopted into local `gh stack` tracking just to work on one layer.
- Check `gh stack --help` for extension availability and `gh stack view --json` for a locally tracked stack. If unavailable or not tracked, do not assume stack metadata; inspect the PRs through the MCP. Each `gh *` invocation goes through Bash and requires its own OMP approval, including reads. Do not route it through Eval.

## Build or maintain

- For new local tracking, only with a clean checkout whose branches are not checked out in other worktrees: `gh stack init --base <trunk> <bottom-branch> <next-branch> ...` adopts existing branches or creates missing ones in bottom-to-top order. `gh stack add <branch>` adds above the current layer. Verify branch ancestry and intended PR bases before remote writes.
- Create or edit individual PRs with the official GitHub MCP; push an individual branch through the normal approval-gated git workflow. Set the bottom PR base to trunk and each higher PR base to the branch below. Preserve existing draft and reviewer state unless requested otherwise.
- To register **existing** PRs as a GitHub stack without local tracking, use `gh stack link <bottom-PR-URL> <next-PR-URL> ...` only after verifying every member and base. Use PR URLs/numbers, not branch arguments: branch arguments can push and create PRs. Linking mutates remote stack membership; check resulting PR bases and stack membership afterward.
- `gh stack submit` pushes every branch, creates PRs, updates existing PR bases, and creates/updates the remote stack. Its interactive editor defaults new PRs to ready; `--auto` skips the editor and defaults new PRs to draft; `--open` can change existing PRs to ready. Prefer individual MCP PR writes plus `link`, not `submit`, when exact titles, bodies, draft states, and targets must be approved in advance.
- Do not use `gh stack sync` as a read or routine update: it fetches, cascade-rebases, force-with-lease atomically pushes branches, and syncs PR/stack state. `gh stack push` also uses force-with-lease and can partially update branches. After review, avoid rebasing away comment anchors; inspect the entire stack before either command.
- For an atomic stack merge, inspect all downstack members first. `gh stack merge` includes every PR below the chosen one; non-interactive or `--yes` can merge the whole stack without a picker. A merge queue may only enqueue it. Do not claim merged until the PRs show merged through the MCP.

Before **each** push, PR change, link, sync, submit, or merge: show the exact repository, branch/PR set, bases, title/body/draft state if applicable, and command/API payload; request explicit approval for that exact remote write and wait. For an operation whose interactive UI conceals the final payload, use individual MCP writes instead. Re-read remote state after a partial or uncertain write before retrying.
