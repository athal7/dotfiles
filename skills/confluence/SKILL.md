---
name: confluence
description: Confluence REST API for wiki pages, spaces, and search
license: MIT
---

Base URL: `https://<your-domain>.atlassian.net/wiki/api/v2`
Auth: HTTP Basic — `$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN`
Secrets: `confluence_base_url`, `confluence_email`, `confluence_api_token`
Spec: https://developer.atlassian.com/cloud/confluence/rest/v2/intro/

Legacy v1 still needed for labels, attachments, and CQL search: `.../wiki/rest/api`

## Gotchas

- Updating a page requires `version.number` incremented — fetch the page first to get current version.
- Page body is storage format (HTML-like XML). Field: `body.storage.value` in both v1 and v2.
- Targeted lookup: `GET /wiki/api/v2/pages?title=...&spaceKey=...`. Pagination: cursor-based in v2 (`?cursor=...`); offset-based in v1 (`?start=0&limit=25`).
- CQL search (v1 only): `GET /wiki/rest/api/content/search?cql=space="KEY"+AND+title~"foo"`

## Whiteboards

Whiteboard visual content (shapes, connectors, sticky notes) is stored in a proprietary format not exposed by any REST API endpoint. `body.storage`, `body.atlas_doc_format`, v2 API, and PDF export all return empty for whiteboards.

**Only way to get text content:** CQL search excerpt. The search index captures text from whiteboard elements:
```
GET /wiki/rest/api/search?cql=id=<whiteboard_id>&excerptSize=5000
```
The `excerpt` field in results contains the text (truncated to ~350 chars regardless of `excerptSize`). For full content, open the whiteboard in a browser.
