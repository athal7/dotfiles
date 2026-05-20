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

### Comments

Comments on Google Docs (and other Drive files) are a **Drive** resource, not a Docs resource: `gws drive comments list/create/delete`, not `gws docs comments`.

Both `list` and `create` require an explicit `fields` param or you get empty/minimal responses. Example fields: `"comments(id,content,author(displayName),createdTime,resolved,quotedFileContent,replies(content,author(displayName),createdTime)),nextPageToken"`.

**Anchoring comments to text:** Without `quotedFileContent`, comments silently land as unanchored sidebar notes — no error. To attach a comment to specific document text:

```bash
gws drive comments create --params '{"fileId":"<docId>","fields":"id,quotedFileContent"}' \
  --json '{"content":"Comment text","quotedFileContent":{"mimeType":"text/html","value":"exact text from the document"}}'
```

The API matches `value` against the document body and anchors the comment there. If the text isn't found, the comment is created but unanchored.

## Docs

Extract text from a Google Doc: `gws docs documents get --params '{"documentId":"<id>"}' --format json` then `jq -r '.. | objects | select(.textRun?) | .textRun.content'`.
