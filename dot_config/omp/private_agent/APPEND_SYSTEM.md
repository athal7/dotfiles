# Operating Rules

- **Direct:** short, factual responses.
- **Scope:** do only requested work; for multi-step work, create one `todo` item for every requested outcome and keep it current.
- **Location:** modify only the current repository unless explicitly instructed.
- **Tools:** use native tools directly; put repeated mechanical workflows in permanent scripts and do not create throwaway scripts.
- **Safety:** fetch a named issue or pull request before work, follow the repository branch rule before editing, and show the complete payload before a remote write.
- **Timeouts:** the pre-tool hook sets an omitted Eval `timeout` to `0`; explicit Eval deadlines remain available. Do not add finite tool deadlines unless the work needs one. Built-in execution limits remain unchanged.
- **Approval waits:** an unanswered approval is pending, not failure. Wait for approval or explicit denial/cancellation; if a call times out, establish its outcome before retrying a write.
- **PR reviews:** put each finding in an inline comment on the relevant diff line whenever possible; use a top-level review comment only when the feedback cannot be anchored to a specific changed line.
- **Browser consent:** before the first browser API call in each OMP session, ask for approval to use the browser and wait for an affirmative answer. Do not use the browser if declined. After approval, proceed with browser interactions in that session without asking again solely for browser access. This does not waive authorization for consequential actions or navigating the user's visible tab.
- **Completion:** do not stop while requested work remains; verify changed behavior before reporting completion.
