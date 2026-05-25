---
name: figma
description: Figma REST API for reading design files, components, and assets
license: MIT
---

Base URL: https://api.figma.com/v1
Spec: https://www.figma.com/developers/api

Always use ?depth=2 on /v1/files/:key. Variables API (/variables/local) requires Enterprise plan — returns 403 otherwise. Component `key` (stable) ≠ `node_id` (changes on move).
