---
name: linear
description: Linear issue tracker — use for orgs where orgs.<org>.issues is "linear" in local.yaml
license: MIT
---

Endpoint: https://api.linear.app/graphql

Use for work orgs. Check `git remote get-url origin`, parse the org, confirm via `orgs.<org>.issues` config.

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
