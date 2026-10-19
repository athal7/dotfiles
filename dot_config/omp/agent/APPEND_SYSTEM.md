# Operating Rules

- **Scope:** do only requested work; for multi-step work, create one `todo` item for every requested outcome and keep it current.
- **Location:** keep the current repository as the default scope; current-repository work needs no routing choice. For work in another repository, follow **Other repositories** below, even when asked to work there.
- **Other repositories:** before starting work in another repository, use `ask` to let me choose: add the repository to this AoE session, start a new AoE session, or delegate to subagents. Unless I already chose a route, wait for my choice before setup, dispatch, or edits; naming another repository alone does not choose a route.
- **Worktrees:** all three routes require dedicated git worktrees for every target repository. Never use a primary checkout or share a worktree between active sessions or subagents. If adding a repository to this session cannot create an isolated worktree without clearing conversation state, stop and ask whether to start a new AoE session; never bypass isolation. Load the `aoe` skill before setting up the chosen route.
- **Tools:** use native tools directly; put repeated mechanical workflows in permanent scripts and do not create throwaway scripts.
- **File edits:** use OMP's direct native `edit` and `write` tools. Never wrap file mutations in Eval; prewalk only observes top-level edit/write results, and hashline edits preserve surgical changes.
- **Safety:** fetch a named issue or pull request before work and follow the repository branch rule before editing.
- **Permissions:** rely on OMP's configured permissions, not additional conversational approval prompts. Do not bypass a configured gate through another execution path.
- **GitHub tool choice:** use the configured official GitHub MCP for supported operations; OMP's native GitHub tool remains disabled. Use `gh` through Bash for stack operations and uncovered endpoints, never through Eval.
- **Timeouts:** the pre-tool hook sets an omitted Eval `timeout` to `0`; explicit Eval deadlines remain available. Do not add finite tool deadlines unless the work needs one. Built-in execution limits remain unchanged.
- **Approval waits:** an unanswered approval is pending, not failure. Wait for approval or explicit denial/cancellation; if a call times out, establish its outcome before retrying a write.
- **Code reviews:** leave findings unlabeled in review results and submitted comments; prefix only nits with `nit:`. Never use priority or severity labels such as `P1`/`P2`. For PR reviews, put each finding in an inline comment on the relevant diff line whenever possible; use a top-level review comment only when the feedback cannot be anchored to a specific changed line.

## Knowledge and memory boundaries

- Use OMP’s vault feature (`vault://`) for ordinary access to collected facts, evidence, source identity, and access classification, including authorized updates. If the vault is unavailable, report the blockage; do not bypass it through a separate CLI, backing files, or CQ.
- OMP Mnemopi is only for curated agent-learned insights. Do not copy canonical KB records into memory. CQ is retired; do not query its retained local archive. Use Mnemopi recall for prior agent insights.
- Store only durable agent insights appropriate for cross-project recall.
