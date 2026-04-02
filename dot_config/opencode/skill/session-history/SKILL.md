---
name: session-history
description: Read and search OpenCode session history — list past sessions, read conversation content, find prior decisions and tool outputs
---

OpenCode session history lives in a SQLite database. Use the `opencode db` command or `opencode session` subcommands to query it.

**DB path:** `~/.local/share/opencode/opencode.db`

## List recent sessions

```bash
# Human-readable list (title, id, date)
opencode session list

# Last 20 sessions for a specific directory, JSON
opencode db --format json "
  SELECT id, title, slug, directory, time_updated
  FROM session
  WHERE directory = '$(pwd)'
  ORDER BY time_updated DESC
  LIMIT 20
"
```

## Search sessions by title or directory

```bash
# Sessions mentioning a keyword in title
opencode db --format json "
  SELECT id, title, directory, datetime(time_updated/1000, 'unixepoch', 'localtime') AS updated
  FROM session
  WHERE title LIKE '%auth%'
  ORDER BY time_updated DESC
  LIMIT 20
"

# All sessions in this repo
opencode db --format json "
  SELECT id, slug, title, datetime(time_updated/1000, 'unixepoch', 'localtime') AS updated
  FROM session
  WHERE directory LIKE '%$(basename $(pwd))%'
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
# All text parts (assistant prose) for a session
opencode db --format json "
  SELECT p.data
  FROM part p
  JOIN message m ON p.message_id = m.id
  WHERE m.session_id = '<sessionID>'
    AND json_extract(p.data, '$.type') = 'text'
  ORDER BY p.time_created
" | jq -r '.[].data | fromjson | .text'
```

## Find tool calls in a session

```bash
# List all tool calls with their inputs
opencode db --format json "
  SELECT
    json_extract(p.data, '$.tool') AS tool,
    json_extract(p.data, '$.state.input') AS input,
    json_extract(p.data, '$.state.status') AS status
  FROM part p
  JOIN message m ON p.message_id = m.id
  WHERE m.session_id = '<sessionID>'
    AND json_extract(p.data, '$.type') = 'tool'
  ORDER BY p.time_created
"

# Filter to bash commands only
opencode db --format json "
  SELECT
    json_extract(p.data, '$.state.input.command') AS command,
    json_extract(p.data, '$.state.input.description') AS description,
    json_extract(p.data, '$.state.metadata.exit') AS exit_code
  FROM part p
  JOIN message m ON p.message_id = m.id
  WHERE m.session_id = '<sessionID>'
    AND json_extract(p.data, '$.tool') = 'bash'
  ORDER BY p.time_created
"
```

## Search across all sessions for a topic

```bash
# Find sessions where a specific file was read or edited
opencode db --format json "
  SELECT DISTINCT s.id, s.title, s.directory,
    datetime(s.time_updated/1000, 'unixepoch', 'localtime') AS updated
  FROM part p
  JOIN message m ON p.message_id = m.id
  JOIN session s ON m.session_id = s.id
  WHERE json_extract(p.data, '$.type') = 'tool'
    AND json_extract(p.data, '$.state.input') LIKE '%opencode.json%'
  ORDER BY s.time_updated DESC
  LIMIT 20
"

# Find sessions that mentioned a term in assistant text
opencode db --format json "
  SELECT DISTINCT s.id, s.title,
    datetime(s.time_updated/1000, 'unixepoch', 'localtime') AS updated
  FROM part p
  JOIN message m ON p.message_id = m.id
  JOIN session s ON m.session_id = s.id
  WHERE json_extract(p.data, '$.type') = 'text'
    AND json_extract(p.data, '$.text') LIKE '%<keyword>%'
  ORDER BY s.time_updated DESC
  LIMIT 20
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

- `opencode db` without arguments opens an interactive `sqlite3` shell
- `opencode db path` prints the DB path for use with external tools
- `opencode db --format tsv "..."` for pipe-friendly output
- Timestamps are Unix milliseconds — divide by 1000 and use `datetime(..., 'unixepoch')` in SQLite
- The DB is in WAL mode; reads are safe while opencode is running
