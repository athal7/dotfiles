---
name: branching
description: Load before creating, restacking, or landing a branch in a git-spice–managed stack — branch naming, stack navigation, and conflict/restack recovery. Use instead of raw git commands whenever the repo has a git-spice stack.
license: MIT
---

`git-spice` CLI — call directly via Bash; read `git-spice --help` on demand.

Always merge stacked branches bottom-up — merge the lowest, then `git-spice repo sync` to restack before merging the next. Custom git aliases: `git stack-log` (graph), `git stack-diff <base>` (diff from merge-base), `git stack-range <base>` (commit range for current layer).
