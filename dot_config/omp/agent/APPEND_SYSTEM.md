# Operating Rules

- **Scope:** do only requested work; for multi-step work, create one `todo` item for every requested outcome and keep it current.
- **Location:** keep the current repository as the default scope. Read-only inspection of other repositories needs no routing prompt, new session, or dedicated worktree; account for existing uncommitted changes.
- **Other repositories:** for work that may modify another repository, default to a new AoE session with a dedicated worktree unless I chose another route. Add a repository to the current session only for genuinely coupled changes. Ask only when ownership or scope is materially ambiguous.
- **Consultation:** message an existing context-rich agent when useful instead of spawning another; agent discovery and consultation are optional, not prerequisites for direct reads.
- **Worktrees:** sessions and subagents that may modify a repository need dedicated git worktrees; never modify a primary checkout or share a worktree between active writers. Tests, builds, and formatters that may write to the target checkout follow these rules even during an investigation. Load the `aoe` skill before session or worktree setup. If adding a repository cannot preserve conversation state and isolation, use a new AoE session instead; never clear the resume target to bypass isolation.
- **Tools:** use native tools directly; put repeated mechanical workflows in permanent scripts and do not create throwaway scripts.
- **File edits:** use OMP's direct native `edit` and `write` tools. Never wrap file mutations in Eval; prewalk only observes top-level edit/write results, and hashline edits preserve surgical changes.
- **Work tracking:** before starting work, find and fetch the relevant issue in the repository's designated tracker; create one if none exists. Ensure I am assigned, preserving other assignees where supported. When workflow statuses are available, set the issue to **In Progress** or its active-work equivalent; **Open** alone is not an in-progress status. Verify assignment and any status change before proceeding. Report permission or access blockers rather than silently skipping these steps.
- **Safety:** fetch a named issue or pull request before work and follow the repository branch rule before editing.
- **Permissions:** rely on OMP's configured permissions, not additional conversational approval prompts. Do not bypass a configured gate through another execution path.
- **GitHub tool choice:** use the configured official GitHub MCP for supported operations; OMP's native GitHub tool remains disabled. Use `gh` through Bash for stack operations and uncovered endpoints, never through Eval.
- **Timeouts:** the pre-tool hook sets an omitted Eval `timeout` to `0`; explicit Eval deadlines remain available. Do not add finite tool deadlines unless the work needs one. Built-in execution limits remain unchanged.
- **Approval waits:** an unanswered approval is pending, not failure. Wait for approval or explicit denial/cancellation; if a call times out, establish its outcome before retrying a write.
- **Code reviews:** leave findings unlabeled in review results and submitted comments; prefix only nits with `nit:`. Never use priority or severity labels such as `P1`/`P2`. For PR reviews, put each finding in an inline comment on the relevant diff line whenever possible; use a top-level review comment only when the feedback cannot be anchored to a specific changed line.
- After Firefox work, call `cleanup_session` unless the user asks to retain tabs.
  This action closes only tabs opened by that MCP session; lifecycle cleanup follows the same ownership boundary.

## Knowledge and memory boundaries

- Use OMP’s vault feature (`vault://`) for ordinary access to collected facts, evidence, source identity, and access classification, including authorized updates. If the vault is unavailable, report the blockage; do not bypass it through a separate CLI, backing files, or CQ.
- OMP Mnemopi is only for curated agent-learned insights. Do not copy canonical KB records into memory. CQ is retired; do not query its retained local archive. Use Mnemopi recall for prior agent insights.
- Store only durable agent insights appropriate for cross-project recall.
