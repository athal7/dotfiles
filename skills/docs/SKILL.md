---
name: docs
description: Read and write documentation — Google Docs via gws CLI and Confluence via confluence CLI. Covers gotchas for both.
license: MIT
metadata:
  provides:
    - docs
---

# Docs

Two tools depending on where the content lives:

| Signal | Tool |
|---|---|
| `.google.com/document` URL, Doc ID, user says "Google Doc" | `gws` |
| `*.atlassian.net/wiki` URL, page ID, user says "Confluence" or "wiki" | `confluence` |

Run `--help` on each tool and subcommand first. This skill covers only what help text won't surface.

## Google Docs

- `gws docs documents get` returns raw structural JSON, not readable text — use `gws drive files export --mimeType text/plain` to get readable content
- `--output` paths must be within the current directory — `gws` rejects absolute paths outside it
- The Docs API has no search — use `gws drive files list` with a CQL `q` param instead
- `gws docs documents get` output begins with a "Using keyring backend" line — strip non-JSON prefix lines before parsing
- Inserting real tables requires a multi-phase approach; see `tables.md`

## Confluence

- `confluence find` matches by exact title — use `confluence search` for partial or full-text matches
- `confluence search` uses CQL — wrap multi-word terms in quotes
- Page IDs appear as `pageId=` in older URLs; newer Confluence Cloud URLs embed the ID in the path — `confluence read` accepts both forms
- Inline comment creation requires editor-generated highlight metadata not exposed by the public REST API — footer comments and replies work reliably, inline creation will 400
