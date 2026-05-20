---
name: gws
description: Google Workspace CLI for email, docs, drive, and sheets
license: MIT
---

`gws` CLI — call directly via Bash; read `gws --help` on demand.

For inserting real tables into Google Docs (not text-based approximations), see [tables.md](tables.md) — the index-shifting across phases is non-obvious.

## Gmail

Helper commands use `--id` flag: `gws gmail +read --id <messageId>`. List messages: `gws gmail users messages list --params '{"userId":"me","q":"search query"}'`.

`+read` output warns about unknown format but works — the body text/html is in the JSON response.

## Calendar

Service name is `calendar`, not `cal`. Events: `gws calendar events list --params '{"calendarId":"primary","timeMin":"...","timeMax":"...","singleEvents":true,"orderBy":"startTime"}'`.

## Drive

Search files: `gws drive files list --params '{"q":"name contains '\''keyword'\''","pageSize":20,"fields":"files(id,name,mimeType,modifiedTime)"}'`.

## Docs

Extract text from a Google Doc: `gws docs documents get --params '{"documentId":"<id>"}' --format json` then `jq -r '.. | objects | select(.textRun?) | .textRun.content'`.
