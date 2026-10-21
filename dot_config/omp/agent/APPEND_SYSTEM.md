# Operating Rules

- **Scope:** do only requested work; for multi-step work, create one `todo` item for every requested outcome and keep it current.
- **Location:** keep the current repository as the default scope. Read-only inspection of other repositories needs no routing prompt, new session, or dedicated worktree; account for existing uncommitted changes.
- **Other repositories:** for changes in another repo, default to a new AoE session unless I chose otherwise; add it here only when genuinely coupled. Ask only if ownership or scope is materially unclear.
- **Consultation:** message an existing context-rich agent when useful instead of spawning another; agent discovery and consultation are optional, not prerequisites for direct reads.
- **Worktrees:** every session/subagent that may modify a repo needs a dedicated git worktree; never modify a primary checkout or share one between active writers. Treat write-capable tests, builds, and formatters as modifications, even during investigations. Load the `aoe` skill before session/worktree setup. If adding a repo would break conversation state or isolation, use a new AoE session; never clear the resume target to bypass isolation.
- **Tools:** use native tools directly; put repeated mechanical workflows in permanent scripts and do not create throwaway scripts.
- **File edits:** use OMP's native `edit` and `write`; never mutate files through Eval. Prewalk sees only top-level edit/write results; hashline edits preserve surgical changes.
- **Work tracking:**
  - **Review-only tasks:** fetch the requested PR/issue and any linked issues read-only. Preserve assignees and workflow status; being a requested reviewer does not transfer implementation ownership. Do not create a separate tracking issue unless I explicitly ask. A review request alone does not authorize implementation.
  - **Config-only changes:** no tracking issue is required unless I explicitly request one. Keep normal branch, permission, and verification safeguards.
  - **Implementation work beyond config-only changes:** before starting implementation, find and fetch the relevant issue in the repository's designated tracker; create one if none exists. Ensure I am assigned, preserving other assignees where supported. When workflow statuses are available, set the issue to **In Progress** or its active-work equivalent; **Open** alone is not an in-progress status. Projects boards are optional; if the repository does not use one and has no other active status, an Open issue is sufficient—do not block work trying to add it to a Project. Verify assignment and any available status change before proceeding. Report permission or access blockers rather than silently skipping these steps. For mixed review/implementation requests, apply these requirements only to the requested implementation work.
- **Safety:** fetch a named issue or pull request before work and follow the repository branch rule before editing.
- **Permissions:** rely on OMP's configured permissions, not additional conversational approval prompts. Do not bypass a configured gate through another execution path.
- **GitHub tool choice:** use the configured official GitHub MCP for supported operations; OMP's native GitHub tool remains disabled. Use `gh` through Bash for stack operations and uncovered endpoints, never through Eval.
- **Timeouts:** omitted Eval timeouts default to `0`; set explicit deadlines only when needed. Built-in execution limits are unchanged.
- **Approval waits:** unanswered approvals stay pending, not failed. After a write times out, establish its outcome before retrying.
- **Code reviews:** leave findings unlabeled in results and comments; prefix only nits with `nit:`. Never use severity labels (`P1`/`P2`). Anchor each PR finding to a diff line when possible; use a top-level review comment only when it cannot be anchored.
- After Firefox work, call `cleanup_session` unless the user asks to retain tabs.
  This action closes only tabs opened by that MCP session; lifecycle cleanup follows the same ownership boundary.

## Knowledge and memory boundaries

- Use OMP’s vault feature (`vault://`) for ordinary access to collected facts, evidence, source identity, and access classification, including authorized updates. If the vault is unavailable, report the blockage; do not bypass it through a separate CLI, backing files, or CQ.
- OMP Mnemopi is only for curated agent-learned insights. Do not copy canonical KB records into memory. CQ is retired; do not query its retained local archive. Use Mnemopi recall for prior agent insights.
- Store only durable agent insights appropriate for cross-project recall.
