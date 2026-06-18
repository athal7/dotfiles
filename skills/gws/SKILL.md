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

**Body/JSON escaping gotcha.** When a `--body`, `--json`, or `--params` value contains apostrophes, quotes, or other shell-special characters, do NOT inline-escape inside single quotes with the `'\''` sequence — it silently corrupts the content (apostrophes come through as literal junk). `--json`/`--params` accept only a JSON string; `@file` and stdin (`-`) are NOT supported. Put the text/JSON in a file and substitute it verbatim: `--body "$(cat body.txt)"` or `--params "$(cat query.json)"`.

## Calendar

Service name is `calendar`, not `cal`. Events: `gws calendar events list --params '{"calendarId":"primary","timeMin":"...","timeMax":"...","singleEvents":true,"orderBy":"startTime"}'`.

## Drive

Search files: write the JSON to a file and substitute it (the query value contains apostrophes — see the Gmail escaping gotcha): `gws drive files list --params "$(cat query.json)"` where `query.json` holds `{"q":"name contains 'keyword'","pageSize":20,"fields":"files(id,name,mimeType,modifiedTime)"}`.

### Comments

Comments on Google Docs (and other Drive files) are a **Drive** resource, not a Docs resource: `gws drive comments list/create/delete`, not `gws docs comments`.

Both `list` and `create` require an explicit `fields` param or you get empty/minimal responses. Example fields: `"comments(id,content,author(displayName),createdTime,resolved,quotedFileContent,replies(content,author(displayName),createdTime)),nextPageToken"`.

**Google Docs comment anchoring does NOT work via the Drive API.** Every comment created through the REST API on a Google Doc displays "Original content deleted" in the UI — regardless of whether you set `anchor`, `quotedFileContent`, both, or neither. The `anchor` field accepts arbitrary JSON but Google Docs ignores it (per Google's own docs: "Google Workspace editor apps treat these comments as un-anchored comments"). The `kix.xxx` IDs on browser-created comments are internal paragraph IDs only the Docs web editor can generate. Do not attempt to re-anchor comments programmatically — distribute the feedback through Slack or another channel instead.

The `anchor` field on browser-created comments (e.g. `"kix.dilskyhp9rug"`) is readable but the format is undocumented and not reproducible via API.

**Replying to existing comments works fine:**

```bash
gws drive replies create --params '{"fileId":"<docId>","commentId":"<commentId>","fields":"id,content"}' \
  --json '{"content":"Reply text"}'
```

## Docs

Extract text from a Google Doc: `gws docs documents get --params '{"documentId":"<id>"}' --format json` then `jq -r '.. | objects | select(.textRun?) | .textRun.content'`.
