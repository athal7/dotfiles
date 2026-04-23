---
name: figma
description: Read Figma files, components, variables, and projects via curl and the REST API
license: MIT
metadata:
  provides:
    - design
  requires:
    - secrets
---

# Figma API Skill

API docs: https://www.figma.com/developers/api

Fetch the docs above when you need endpoint details. Use `jq` to process responses.

## Auth

Use your `secrets` capability to fetch `FIGMA_ACCESS_TOKEN` before making requests.

```bash
# Header: X-Figma-Token: $FIGMA_ACCESS_TOKEN  (NOT "Authorization: Bearer")
curl -s "https://api.figma.com/v1/me" -H "X-Figma-Token: $FIGMA_ACCESS_TOKEN" | jq .
```

## Finding IDs

| What | Where |
|------|-------|
| File key | Figma URL: `figma.com/file/{FILE_KEY}/` |
| Team ID | Figma URL: `figma.com/files/team/{TEAM_ID}/` |
| Node ID | Right-click layer → Copy link → `?node-id=123-456` → use `123:456` (hyphens → colons) |

## Gotchas

- Auth header is `X-Figma-Token` — not `Authorization: Bearer`
- Always use `?depth=2` on `GET /v1/files/:key` — the full tree can be many MB
- Variables API (`/variables/local`) requires Enterprise plan — returns 403 otherwise
- Component `key` (stable) ≠ `node_id` (can change on move)
- Image export URLs expire after 30 days
