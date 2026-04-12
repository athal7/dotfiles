---
name: linear
description: Query and update Linear issues, projects, and teams via curl and the GraphQL API
license: MIT
metadata:
  author: athal7
  version: "1.0"
  provides:
    - issues
---

# Linear API Skill

API docs: https://developers.linear.app/docs/graphql/working-with-the-graphql-api
GraphQL explorer: https://studio.apollographql.com/public/Linear-API/variant/current/explorer

Fetch the docs above when you need query/mutation syntax. Use `jq` to process responses.

## Auth

```bash
# Requires: $LINEAR_API_KEY, $LINEAR_TEAM_ID
export GQ_ENDPOINT=https://api.linear.app/graphql
export GQ_HEADER_Authorization="$LINEAR_API_KEY"  # no "Bearer" prefix
```

## Usage

Use `gq` (graphqurl) for all queries. Variables are passed as `key=value` after the query.

```bash
# Query
gq $GQ_ENDPOINT -H "Authorization: $LINEAR_API_KEY" \
  -q '{ viewer { id name email } }' | jq .

# Query with variables
gq $GQ_ENDPOINT -H "Authorization: $LINEAR_API_KEY" \
  -q 'query($id: String!) { issue(id: $id) { identifier title description state { name } } }' \
  -v id=ENG-123 | jq .data.issue

# Mutation
gq $GQ_ENDPOINT -H "Authorization: $LINEAR_API_KEY" \
  -q 'mutation($input: CommentCreateInput!) { commentCreate(input: $input) { success } }' \
  -v 'input={"issueId":"ENG-123","body":"Fix in progress."}' | jq .
```

## Gotchas

- No `Bearer` prefix — use the raw key directly in `Authorization`
- `id` fields accept both UUID and human identifier (e.g. `"ENG-123"`)
- Always add `first: N` to connections to avoid high complexity cost
- Rate limit: ~1,500 req/hr (complexity-based); check `X-RateLimit-*` response headers
- Before any write, show the proposed change and get explicit user approval
- **`gq` does not expand shell env vars inside `-q` strings** — use `--queryFile` for queries needing template values, and `-v key=value` for runtime variables
