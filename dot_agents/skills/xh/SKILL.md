---
name: xh
description: HTTPie-compatible HTTP client for REST API calls
license: MIT
---

`xh` CLI — HTTPie-compatible, cleaner than curl.

## Syntax

```
xh --ignore-stdin --session=agent [METHOD] https://endpoint Key:Value [key=value] [key==value]
```

- **Headers:** `Key:Value` (no space after colon)
- **JSON body:** `key=value` (string) or `key:=value` (raw JSON)
- **Query params:** `key==value`
- **Method:** optional first arg — defaults to GET, inferred POST if body present
- **Body-less POST:** `xh --ignore-stdin --session=agent --json POST https://...`

## `--ignore-stdin`

Always use `--ignore-stdin` in agent/non-TTY contexts. Without it, xh tries to read stdin and conflicts with body arguments.

## Sessions

Sessions are pre-configured per host at `chezmoi apply` time. `--session=agent` resolves the correct credentials for each host automatically.

Never pass an `Authorization:` header or a `$*_API_KEY` value — the session already carries the credentials for the host.

If a request returns 401, the session may be stale — re-run `chezmoi apply` to refresh.

## GraphQL

Pass query as a string field and variables as raw JSON:

```bash
xh --ignore-stdin --session=agent POST https://api.example.com/graphql \
  query='{ issues { nodes { id title } } }' \
  variables:='{"id":"ABC-123"}'
```

Queries are read-only; mutations modify data and may require `ask` permission.

## File input

`@/path/to/file.json` sends a file as the request body (useful for complex JSON like ES queries):

```bash
xh --ignore-stdin --session=agent POST https://api.example.com/search @/tmp/query.json
```

Cannot mix `@file` with `key=value` body items — pick one per request. Alternative for inline complex JSON: `key:='{"nested":"json"}'` — single-quoted bash avoids escaping inner double quotes.
