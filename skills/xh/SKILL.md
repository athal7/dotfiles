---
name: xh
description: HTTPie-compatible HTTP client for REST API calls
license: MIT
---

`xh` CLI — HTTPie-compatible, cleaner than curl.

## Syntax

```
xh [METHOD] https://endpoint Key:Value [key=value] [key==value]
```

- **Headers:** `Key:Value` (no space after colon) — e.g. `Authorization:"Bearer $TOKEN"`
- **JSON body:** `key=value` (string) or `key:=value` (raw JSON)
- **Query params:** `key==value`
- **Method:** optional first arg — defaults to GET, inferred POST if body present
- **Body-less POST:** `xh --json POST https://...`

## `--ignore-stdin`

Always use `--ignore-stdin` in agent/non-TTY contexts. Without it, xh tries to read stdin and conflicts with body arguments.

## Sessions

`--session=<name>` persists auth headers across requests to the same host. Name sessions after the service (e.g., `--session=slack`).

Before creating a session, check if one exists: `ls ~/.config/xh/sessions/<hostname>/`. Sessions are host-scoped.

If no session exists, seed one by including the auth header on the first request — use `$VARIABLE` from the API skill's Auth line. Subsequent requests reuse auth automatically.

**Stale session (401)?** Re-include the auth header on the next request to update the session.

## GraphQL

Pass query as a string field and variables as raw JSON:

```bash
xh --ignore-stdin --session=myapi POST https://api.example.com/graphql \
  query='{ issues { nodes { id title } } }' \
  variables:='{"id":"ABC-123"}'
```

Queries are read-only; mutations modify data and may require `ask` permission.

## File input

`@/path/to/file.json` sends a file as the request body (useful for complex JSON like ES queries):

```bash
xh --ignore-stdin POST https://api.example.com/search @/tmp/query.json
```

Cannot mix `@file` with `key=value` body items — pick one per request. Alternative for inline complex JSON: `key:='{"nested":"json"}'` — single-quoted bash avoids escaping inner double quotes.
