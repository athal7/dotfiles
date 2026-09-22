---
name: implement
description: Load only when the user invokes /implement or explicitly requests the end-to-end implementation workflow
license: MIT
---

- Read the named issue or pull request.
- Follow the repository branch and worktree rules.
- Inspect relevant source, history, and callers.
- Reuse one existing convention.
- Implement every requested outcome.
- Migrate all callers of changed contracts.
- Remove obsolete paths.
- Verify the affected runtime surface.
- Load `shipit` only when the user requests a commit, push, or deploy.
