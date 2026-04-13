---
name: gws
description: Google Workspace CLI — docs, drive, gmail, calendar, chat via the gws binary
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  provides:
    - docs
    - email
---

# Skill: gws

Google Workspace CLI (`gws`) gotchas that `--help` won't tell you.

## Reading a Google Doc

**Do not use `gws docs documents get` to read content** — it returns the raw Docs JSON structural format (paragraphs, runs, elements), which is verbose and hard to work with. Export as plain text instead:

```bash
# Export to a temp file, then read it
gws drive files export \
  --params '{"fileId": "DOC_ID", "mimeType": "text/plain"}' \
  -o /tmp/doc.txt
cat /tmp/doc.txt
```

Use `gws docs documents get` only when you need structural info (e.g. finding element indices for `batchUpdate`).

## Finding a document by name

Search via Drive, not Docs — the Docs API has no search:

```bash
# Search by name (partial match, Drive query syntax)
gws drive files list \
  --params '{"q": "name contains '\''My Doc'\'' and mimeType='\''application/vnd.google-apps.document'\'' and trashed=false", "fields": "files(id,name,modifiedTime,webViewLink)", "pageSize": 10}'

# Most recently modified docs
gws drive files list \
  --params '{"q": "mimeType='\''application/vnd.google-apps.document'\'' and trashed=false", "orderBy": "modifiedTime desc", "fields": "files(id,name,modifiedTime,webViewLink)", "pageSize": 10}'
```

The `id` field is the document ID used in all other commands.

## Creating a document

```bash
# Create blank doc with title
gws docs documents create --json '{"title": "My New Document"}'

# Returns the full document object — grab the documentId
gws docs documents create --json '{"title": "My Doc"}' | jq -r '.documentId'
```

After creating, the doc exists but has no content. Use `+write` or `batchUpdate` to add content.

## Writing to a document

For plain text appends, use the `+write` helper:

```bash
gws docs +write --document DOC_ID --text "Text to append at end"
```

For rich formatting, headings, or inserting at a specific position, use `batchUpdate` with the Docs structural API. This is complex — only use it when formatting matters.

## Sharing / permissions

Use Drive permissions, not Docs:

```bash
# Share with a user (writer)
gws drive permissions create \
  --params '{"fileId": "DOC_ID", "sendNotificationEmail": false}' \
  --json '{"role": "writer", "type": "user", "emailAddress": "user@example.com"}'

# Make publicly readable
gws drive permissions create \
  --params '{"fileId": "DOC_ID"}' \
  --json '{"role": "reader", "type": "anyone"}'
```

## Gmail

```bash
# List recent messages (unread in inbox)
gws gmail users messages list \
  --params '{"userId": "me", "q": "is:unread in:inbox", "maxResults": 10}'

# Get a message (returns base64-encoded parts)
gws gmail users messages get \
  --params '{"userId": "me", "id": "MSG_ID", "format": "full"}'

# Send a message (RFC 2822, base64url-encoded)
gws gmail users messages send \
  --params '{"userId": "me"}' \
  --json '{"raw": "BASE64URL_ENCODED_RFC2822"}'
```

For sending email, prefer using the `gws workflow` helpers if available — raw RFC 2822 construction is error-prone.

## Pagination

For large result sets, use `--page-all`:

```bash
gws drive files list \
  --params '{"q": "...", "pageSize": 100}' \
  --page-all \
  --page-limit 5
```

Output is NDJSON (one JSON object per page) — pipe through `jq -s '[.[].files[]]'` to flatten.
