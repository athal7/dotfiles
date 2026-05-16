---
name: linear
description: Linear issue tracker — use for orgs where orgs.<org>.issues is "linear" in local.yaml
license: MIT
metadata:
  provides:
    - issues
  requires:
    - graphql
---

Endpoint: https://api.linear.app/graphql
Auth: `Authorization: Bearer $LINEAR_API_KEY`

Use for work orgs. Check `git remote get-url origin`, parse the org, confirm via `orgs.<org>.issues` config.

## Project Body

The project body is `documentContent.content` — not the legacy `description` field. Write via `projectUpdate` with the `content` field. `documentCreate` with `projectId` creates an attached document (Documents tab) — not the inline body. The UI may need a hard refresh after writes.

## Templates

Templates apply automatically in the web UI but not via the API. Query `{ templates { id name templateData } }` and follow the template manually.
