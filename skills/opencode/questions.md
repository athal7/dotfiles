When a session is paused waiting for a `question` tool response, use the `/question` API to unblock it. This applies to any session — worktree or main — that a user or another agent has left waiting.

## Find pending questions

```bash
# List all pending questions for a session's directory
curl -s "http://localhost:4096/question?directory=<session-directory>" | jq '.'
# Returns: [{ "id": "que_...", "sessionID": "...", "questions": [...] }]
```

The `directory` must be the session's exact working directory (for worktree sessions, the worktree path — not the repo root). Find it from the session record if unsure:

```bash
DB=~/.local/share/opencode/opencode.db
sqlite3 -json "$DB" "SELECT directory FROM session WHERE id = '<sessionID>'" | jq -r '.[0].directory'
```

## Reply

```bash
curl -s -X POST "http://localhost:4096/question/<que_id>/reply?directory=<session-directory>" \
  -H "Content-Type: application/json" \
  -d '{"answers": [["<option label or free-text>"]]}' | jq '.'
# Returns: true on success
```

`answers` is an array-of-arrays — one inner array per question in the request. The value can be any of the listed option labels, or arbitrary free text.

## What doesn't work

- **Message endpoint** — `POST /session/:id/message` with a `tool-result` part is rejected. Plain text messages don't unblock a waiting question either.
- **`/doc` spec** — returns a 3KB stub with only 2 routes. It does not list `/question` or most session endpoints; don't rely on it to discover the API surface.
