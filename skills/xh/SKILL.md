---
name: xh
description: HTTPie-compatible HTTP client for REST API calls
license: MIT
metadata:
  provides:
    - rest
  requires:
    - secrets
---

`xh` CLI — HTTPie-compatible, cleaner than curl.

xh [METHOD] https://[endpoint] Key:Value [key=value] [key==value]

- Headers: `Key:Value` (no space after colon)
- JSON body items: `key=value` (string) or `key:=value` (raw JSON)
- Query params: `key==value`
- Method is optional first positional arg — defaults to GET, inferred POST if body present

Auth header goes inline: `Authorization:"Bearer $TOKEN"` or `X-Custom-Header:$VALUE`

For APIs requiring a body-less POST: `xh --json POST https://...`
