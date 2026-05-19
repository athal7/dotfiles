---
name: confluence
description: Confluence REST API for wiki pages, spaces, and search
license: MIT
---

Base URL: `https://<your-domain>.atlassian.net/wiki/api/v2`
Auth: `-a "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN"` (xh basic auth flag)
Secrets: `CONFLUENCE_BASE_URL`, `CONFLUENCE_EMAIL`, `CONFLUENCE_API_TOKEN`
Spec: https://developer.atlassian.com/cloud/confluence/rest/v2/intro/

Legacy v1 still needed for labels, attachments, and CQL search: `.../wiki/rest/api`

## Gotchas

- Updating a page requires `version.number` incremented — fetch the page first to get current version.
- Page body is storage format (HTML-like XML). Field: `body.storage.value` in both v1 and v2.
- Targeted lookup: `GET /wiki/api/v2/pages?title=...&spaceKey=...`. Pagination: cursor-based in v2 (`?cursor=...`); offset-based in v1 (`?start=0&limit=25`).
- CQL search (v1 only): `GET /wiki/rest/api/content/search?cql=space="KEY"+AND+title~"foo"`
