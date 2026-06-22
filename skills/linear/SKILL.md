---
name: linear
description: Linear issue tracker — use for orgs whose `orgs.<org>.issues` is "linear" in chezmoi data
license: MIT
---

Endpoint: https://api.linear.app/graphql

## Org detection

Check `git remote get-url origin`, parse the GitHub org, then confirm it uses Linear:

```bash
chezmoi data --format json | jq '.orgs["<org>"].issues'
```

If the result is `"linear"`, this org tracks issues in Linear. The org config lives in `~/.local/share/chezmoi/.chezmoidata/local.yaml` under `orgs.<org>.issues`.

## Project Body

The project body is the `content` field (markdown) on `projectCreate` / `projectUpdate` mutations — not the legacy `description` field (short summary). `documentCreate` with `projectId` creates an attached document (Documents tab) — not the inline body.

## Templates

Templates apply automatically in the web UI but not via the API. Query `{ templates { id name templateData } }` and follow the template manually.

## Search

`issueSearch` is deprecated (returns 400). Use `searchIssues` instead:
```graphql
{ searchIssues(term: "query", first: 10) { nodes { identifier title state { name } url } } }
```

## Project Milestones

Create milestones on a project with `projectMilestoneCreate`. Assign issues to milestones via `projectMilestoneId` in `issueCreate`.

```graphql
mutation($input: ProjectMilestoneCreateInput!) {
  projectMilestoneCreate(input: $input) { success projectMilestone { id name } }
}
# input: { name, projectId, sortOrder }
```

## Comments

`commentCreate` accepts multiple parent fields (`issueId`, `projectId`, `projectUpdateId`, `documentContentId`, `postId`) but only include the one you're using. Passing `null` for unused parent fields causes "missing parent entity" even if another valid parent is set.

## Project Status Field

Query project status with `status { name }`, not `state { name }`. The `state` field is a plain `String!` — using a selection set on it returns a 400 validation error.
