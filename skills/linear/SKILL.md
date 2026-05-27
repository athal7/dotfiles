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

The project body is `documentContent.content` — not the legacy `description` field. Write via `projectUpdate` with the `content` field. `documentCreate` with `projectId` creates an attached document (Documents tab) — not the inline body. The UI may need a hard refresh after writes.

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
