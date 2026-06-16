When a session is paused waiting for a `question` tool response, use the v2 question API (`/api/question/request` to list, `/api/session/{sessionID}/question/{requestID}/reply` to answer) to unblock it. The `opencode-cmd questions` / `reply` commands wrap these. This applies to any session — worktree or main — that a user or another agent has left waiting.

## Find pending questions

```bash
# List all pending questions for a session's directory
opencode-cmd -d "<session-directory>" questions
# Returns: [{ "id": "que_...", "sessionID": "...", "questions": [...] }]
```

The `directory` must be the session's exact working directory (for worktree sessions, the worktree path — not the repo root). Find it from the session record if unsure:

```bash
DB=~/.local/share/opencode/opencode.db
sqlite3 -json "$DB" "SELECT directory FROM session WHERE id = '<sessionID>'" | jq -r '.[0].directory'
```

## Reply

```bash
opencode-cmd -d "<session-directory>" reply "<que_id>" "<option label or free-text>"
# Returns: true on success
```

`answers` is an array-of-arrays — one inner array per question in the request. The value can be any of the listed option labels, or arbitrary free text.

## What doesn't work

- **Message endpoint** — `POST /session/:id/message` with a `tool-result` part is rejected. Plain text messages don't unblock a waiting question either.
- **Legacy vs v2** — question list and reply now use the v2 `/api/*` endpoints (via `opencode-cmd questions` / `reply`). The v2 reply path is session-scoped, so `reply` resolves the `sessionID` from the question list internally — the CLI signature (`reply QID ANSWER`) is unchanged. The server health probe is `GET /api/health`. The `/doc` endpoint returns the full OpenAPI spec (useful for discovering the v2 surface).
