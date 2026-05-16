---
name: gq
description: GraphQL client for querying and mutating GraphQL APIs
license: MIT
metadata:
  provides:
    - graphql
  requires:
    - secrets
---

`gq` CLI (graphqurl) — GraphQL queries and mutations from the terminal.

gq https://[endpoint] -H "Authorization: Bearer $TOKEN" -q '{ ... }'

Variables: `-v '{"key": "value"}'`
Introspect schema: `gq https://[endpoint] --introspect`
Mutation example:
  gq https://[endpoint] \
    -H "Authorization: Bearer $TOKEN" \
    -q 'mutation($id: String!) { update(id: $id) { success } }' \
    -v '{"id": "abc"}'
