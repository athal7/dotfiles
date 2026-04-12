---
name: session-history
description: Read and search OpenCode session history — list past sessions, read conversation content, find prior decisions and tool outputs
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides: read-sessions list-sessions search-sessions
---

OpenCode session history lives in a SQLite database. Use `opencode session list` for a quick human-readable list, or query the DB directly with `sqlite3` for anything more specific.

**DB path:** `~/.local/share/opencode/opencode.db`

```bash
DB=~/.local/share/opencode/opencode.db
```

## List recent sessions

```bash
# Human-readable list (title, id, date)
opencode session list

# Last 20 sessions for a specific directory
sqlite3 -json "$DB" "
  SELECT id, title, slug, directory, datetime(time_updated/1000,'unixepoch','localtime') AS updated
  FROM session
  WHERE directory = '$(pwd)'
  ORDER BY time_updated DESC LIMIT 20
"
```

## Search sessions by title or directory

```bash
# Sessions mentioning a keyword in title
sqlite3 -json "$DB" "
  SELECT id, title, directory, datetime(time_updated/1000,'unixepoch','localtime') AS updated
  FROM session WHERE title LIKE '%auth%'
  ORDER BY time_updated DESC LIMIT 20
"

# All sessions in this repo
sqlite3 -json "$DB" "
  SELECT id, slug, title, datetime(time_updated/1000,'unixepoch','localtime') AS updated
  FROM session WHERE directory LIKE '%$(basename $(pwd))%'
  ORDER BY time_updated DESC
"
```

## Export a full session (messages + parts)

```bash
# JSON export — includes all messages and content parts
opencode export <sessionID>

# Save to file
opencode export <sessionID> > session-dump.json
```

## Read conversation text from a session

```bash
sqlite3 -json "$DB" "
  SELECT p.data FROM part p
  JOIN message m ON p.message_id = m.id
  WHERE m.session_id = '<sessionID>'
    AND json_extract(p.data, '$.type') = 'text'
  ORDER BY p.time_created
" | jq -r '.[].data | fromjson | .text'
```

## Find tool calls in a session

```bash
# All tool calls
sqlite3 -json "$DB" "
  SELECT json_extract(p.data,'$.tool') AS tool,
    json_extract(p.data,'$.state.input') AS input,
    json_extract(p.data,'$.state.status') AS status
  FROM part p JOIN message m ON p.message_id = m.id
  WHERE m.session_id = '<sessionID>'
    AND json_extract(p.data,'$.type') = 'tool'
  ORDER BY p.time_created
"

# Bash commands only
sqlite3 -json "$DB" "
  SELECT json_extract(p.data,'$.state.input.command') AS command,
    json_extract(p.data,'$.state.input.description') AS description,
    json_extract(p.data,'$.state.metadata.exit') AS exit_code
  FROM part p JOIN message m ON p.message_id = m.id
  WHERE m.session_id = '<sessionID>'
    AND json_extract(p.data,'$.tool') = 'bash'
  ORDER BY p.time_created
"
```

## Search across all sessions for a topic

```bash
# Sessions where a specific file was touched
sqlite3 -json "$DB" "
  SELECT DISTINCT s.id, s.title, s.directory,
    datetime(s.time_updated/1000,'unixepoch','localtime') AS updated
  FROM part p JOIN message m ON p.message_id = m.id
  JOIN session s ON m.session_id = s.id
  WHERE json_extract(p.data,'$.type') = 'tool'
    AND json_extract(p.data,'$.state.input') LIKE '%opencode.json%'
  ORDER BY s.time_updated DESC LIMIT 20
"

# Sessions that mentioned a term in assistant text
sqlite3 -json "$DB" "
  SELECT DISTINCT s.id, s.title,
    datetime(s.time_updated/1000,'unixepoch','localtime') AS updated
  FROM part p JOIN message m ON p.message_id = m.id
  JOIN session s ON m.session_id = s.id
  WHERE json_extract(p.data,'$.type') = 'text'
    AND json_extract(p.data,'$.text') LIKE '%<keyword>%'
  ORDER BY s.time_updated DESC LIMIT 20
"
```

## Continue or fork a past session

```bash
# Continue the last session
opencode -c

# Continue a specific session
opencode -s <sessionID>

# Fork from a specific session (branches from that point)
opencode -s <sessionID> --fork
```

## Schema reference

**`session`**: `id`, `title`, `slug`, `directory`, `project_id`, `workspace_id`, `parent_id`, `share_url`, `summary_additions`, `summary_deletions`, `summary_files`, `summary_diffs`, `time_created`, `time_updated`, `time_archived`

**`message`**: `id`, `session_id`, `data` (JSON with `role`, `agent`, `model`, `providerID`, `cost`, `tokens`)

**`part`**: `id`, `message_id`, `session_id`, `data` (JSON with `type: "text"|"tool"`)

- **text part**: `{ type, text, time: { start, end } }`
- **tool part**: `{ type, callID, tool, state: { status, input, output, title, metadata, time } }`

## Tips

- `sqlite3 "$DB"` opens an interactive shell for ad-hoc queries
- Timestamps are Unix milliseconds — divide by 1000 and use `datetime(...,'unixepoch')` in SQLite
- The DB is in WAL mode; reads are safe while opencode is running
- `sqlite3 -json` returns JSON arrays; pipe to `jq` for filtering
