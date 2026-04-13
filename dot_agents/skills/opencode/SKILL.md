---
name: opencode
description: OpenCode agent runtime — manage sessions, dispatch tasks, repair DB issues, reset diffs, capture learnings after surprising failures or discoveries, and audit agent instructions and skills
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - agent
---

Unified skill for all OpenCode agent runtime operations. Use the reference files below for each area.

- **[sessions.md](sessions.md)** — list, search, read, and continue past OpenCode sessions via the SQLite DB or CLI
- **[dispatch.md](dispatch.md)** — spawn or reuse an OpenCode session in another workspace to perform a task
- **[repair.md](repair.md)** — fix blank sessions, missing worktrees, duplicate project rows, and DB issues
- **[reset-diff.md](reset-diff.md)** — fix stale or noisy "Modified Files" sidebar after a commit, rebase, or merge
- **[learn.md](learn.md)** — capture non-obvious learnings into AGENTS.md or a new skill so they persist across sessions
- **[audit.md](audit.md)** — review and optimize agent instructions, skills, and config hierarchy
