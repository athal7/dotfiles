---
name: figma
description: Figma REST API for reading design files, components, and assets
license: MIT
metadata:
  provides:
    - design
  requires:
    - rest
---

Base URL: https://api.figma.com/v1
Auth: `X-Figma-Token: $FIGMA_ACCESS_TOKEN` (non-standard header — not Authorization)
Spec: https://www.figma.com/developers/api

Always use ?depth=2 on /v1/files/:key. Variables API (/variables/local) requires Enterprise plan — returns 403 otherwise. Component `key` (stable) ≠ `node_id` (changes on move).
