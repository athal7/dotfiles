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

Run `gws --help` and `gws <service> <subcommand> --help` to discover commands. This skill only documents silent failure modes that help text won't surface.

## Reading a Google Doc — use Drive export, not Docs get

`gws docs documents get` returns raw Docs structural JSON (paragraphs, runs, element indices), not readable text. Export via Drive instead:

```bash
gws drive files export \
  --params '{"fileId": "DOC_ID", "mimeType": "text/plain"}' \
  -o /tmp/doc.txt
```

Use `gws docs documents get` only when you need structural info for a `batchUpdate` (e.g. finding insertion indices).

## Finding a doc by name — use Drive search, not Docs

The Docs API has no search. Search via Drive:

```bash
gws drive files list \
  --params '{"q": "name contains '\''My Doc'\'' and mimeType='\''application/vnd.google-apps.document'\'' and trashed=false", "fields": "files(id,name,modifiedTime,webViewLink)"}'
```

The `id` from results is the `documentId` used in all Docs commands.
