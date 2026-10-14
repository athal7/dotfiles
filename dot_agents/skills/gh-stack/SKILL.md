---
name: gh-stack
description: Load when deciding whether to use gh stack or working on dependent, stacked GitHub pull requests
license: MIT
---

## Choose the path

- Fetch a named PR first. Inspect its base, head, and downstack PRs with the official GitHub MCP; a branch name or installed extension alone does not establish a stack.
- Keep changes small and independently reviewable. Use `gh stack` when dependent PRs form a stack; one independent PR uses the normal GitHub workflow. The dotfiles repository deploys without PRs.
- Check `gh stack --help` for extension availability and `gh stack view --json` for a locally tracked stack. If unavailable or untracked, do not assume stack metadata; inspect PRs through the MCP. Run CLI operations through Bash, not Eval.

## Build or maintain

- Initialize local tracking only from a clean checkout whose branches are not checked out in other worktrees: `gh stack init --base <trunk> <bottom-branch> <next-branch> ...` adopts existing branches or creates missing ones in bottom-to-top order. `gh stack add <branch>` adds above the current layer. Verify branch ancestry and intended PR bases.
- Create or edit individual PRs with the official GitHub MCP. Set the bottom PR base to trunk and each higher PR base to the branch below. Preserve existing draft and reviewer state.
- To register existing PRs without local tracking, use `gh stack link <bottom-PR-URL> <next-PR-URL> ...` only after verifying each member and base. Use PR URLs/numbers, not branch arguments: branch arguments can push and create PRs. Check resulting PR bases and stack membership.
- `gh stack submit` pushes every branch, creates PRs, updates existing PR bases, and creates or updates the remote stack. Its interactive editor defaults new PRs to ready; `--auto` skips the editor and defaults new PRs to draft; `--open` can change existing PRs to ready. Inspect intended titles, bodies, draft states, and targets before submitting.
- Do not use `gh stack sync` as a read or routine update: it fetches, cascade-rebases, force-with-lease pushes branches atomically, and syncs PR/stack state. `gh stack push` also uses force-with-lease and can partially update branches. Inspect the entire stack before either command; after review, avoid rebasing away comment anchors.
- `gh stack merge` includes every PR below the selected one. Inspect all downstack members before merging; non-interactive or `--yes` can merge the whole stack without a picker. A merge queue may only enqueue it. Verify PRs show merged through the MCP before claiming completion.

OMP permissions configuration governs prompts. Do not add conversational approval requests or bypass configured gates. Re-read remote state after a partial or uncertain write before retrying it.
