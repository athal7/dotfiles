---
name: google-docs
description: Read and write Google Docs via gws CLI — search, export, format, and insert real tables
license: MIT
metadata:
  author: athal7
  version: "1.0"
  provides:
    - docs
---

# Google Docs via `gws`

Run `gws --help` and `gws docs --help` for full command reference. This skill covers gotchas and non-obvious patterns.

## Reading a doc

`gws docs documents get` returns raw structural JSON (paragraph elements with indices), not readable text. To get readable content:

```bash
gws drive files export --params '{"fileId":"DOC_ID","mimeType":"text/plain"}' -o ./doc.txt
```

Output path must be within the current directory — `gws` rejects absolute paths outside it.

## Finding a doc

The Docs API has no search. Use Drive:

```bash
gws drive files list --params '{"q": "name contains '\''search term'\''", "fields": "files(id,name,modifiedTime)", "pageSize": "10"}'
```

## Writing text

Append text (simple):
```bash
gws docs +write --document DOC_ID --text 'Hello, world!'
```

For full control, use `batchUpdate` with `insertText` / `deleteContentRange` requests.

## Comments

```bash
# List comments
gws drive comments list --params '{"fileId":"DOC_ID","fields":"comments(id,content,quotedFileContent,author(displayName),createdTime,resolved,replies(content,author(displayName),createdTime))"}'

# Reply to a comment
gws drive replies create --params '{"fileId":"DOC_ID","commentId":"COMMENT_ID","fields":"id,content"}' --json '{"content": "Reply text"}'
```

## Formatting via batchUpdate

Apply heading styles, bold, italic, bullets:

```bash
gws docs documents batchUpdate --params '{"documentId":"DOC_ID"}' --json '{"requests": [
  {"updateParagraphStyle": {"range": {"startIndex": 1, "endIndex": 44}, "paragraphStyle": {"namedStyleType": "HEADING_1"}, "fields": "namedStyleType"}},
  {"updateTextStyle": {"range": {"startIndex": 10, "endIndex": 30}, "textStyle": {"bold": true}, "fields": "bold"}},
  {"createParagraphBullets": {"range": {"startIndex": 50, "endIndex": 100}, "bulletPreset": "BULLET_DISC_CIRCLE_SQUARE"}}
]}'
```

To find character indices, use `gws docs documents get` with `fields=body.content(paragraph(elements(startIndex,endIndex,textRun(content))))`.

## Inserting real tables

Text-based tables (arrow-delimited) are not proper Google Docs tables. Converting them requires a multi-phase approach. See `tables.md` for the full process and gotchas.
