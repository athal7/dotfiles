# Operating Rules

- **Scope:** do only requested work; for multi-step work, create one `todo` item for every requested outcome and keep it current.
- **Location:** modify only the current repository unless explicitly instructed.
- **Tools:** use native tools directly; put repeated mechanical workflows in permanent scripts and do not create throwaway scripts.
- **Safety:** fetch a named issue or pull request before work, follow the repository branch rule before editing, and show the complete payload before a remote write.
- **GitHub writes:** before a push or PR creation, update, review, comment, or review-thread resolution, request explicit approval for the exact target and payload and wait for it. This applies to MCP tools, shell commands, scripts, and Eval; an allowed execution tool does not waive this check.
- **GitHub tool choice:** use the configured official GitHub MCP for supported operations; OMP's native GitHub tool remains disabled. For uncovered endpoints, `gh` CLI is allowed through Bash, and each `gh *` command must receive OMP approval. Do not bypass this prompt through Eval or another execution path. GitHub writes still require explicit approval for the exact target and payload.
- **Timeouts:** the pre-tool hook sets an omitted Eval `timeout` to `0`; explicit Eval deadlines remain available. Do not add finite tool deadlines unless the work needs one. Built-in execution limits remain unchanged.
- **Approval waits:** an unanswered approval is pending, not failure. Wait for approval or explicit denial/cancellation; if a call times out, establish its outcome before retrying a write.
- **Code reviews:** leave findings unlabeled in review results and submitted comments; prefix only nits with `nit:`. Never use priority or severity labels such as `P1`/`P2`. For PR reviews, put each finding in an inline comment on the relevant diff line whenever possible; use a top-level review comment only when the feedback cannot be anchored to a specific changed line.
- **Browser consent:** before the first browser API call in each OMP session, ask for approval to use the browser and wait for an affirmative answer. Do not use the browser if declined. After approval, proceed with browser interactions in that session without asking again solely for browser access. This does not waive authorization for consequential actions or navigating the user's visible tab.

## Knowledge and memory boundaries

- The KB Markdown vault and kb workflow own canonical collected facts, evidence, source identity, and access classification. Use the KB workflow for those records.
- OMP Mnemopi is only for curated agent-learned insights. Do not copy canonical KB records into memory. CQ is retired; do not query its retained local archive. Use Mnemopi recall for prior agent insights.
- Store only durable agent insights appropriate for cross-project recall.
