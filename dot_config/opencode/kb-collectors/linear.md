---
name: linear
priority: 3
authoritative_for: [tickets, completed-work]
description: Linear issues you touched in the enrichment window
---

## Enabled check

Load the `linear` skill. If no Linear API token is available (the skill cannot authenticate), skip this collector and log "linear: no auth, skipping".

## How to query

Use the Linear GraphQL API (endpoint `https://api.linear.app/graphql`) via the `linear` skill. Query issues assigned to or created by you that were updated within the enrichment window:

```graphql
{
  issues(
    filter: {
      updatedAt: { gte: "YYYY-MM-DDT00:00:00Z" }
      or: [
        { assignee: { isMe: { eq: true } } }
        { creator: { isMe: { eq: true } } }
      ]
    }
    first: 50
  ) {
    nodes {
      identifier
      title
      state { name }
      updatedAt
      description
      url
    }
  }
}
```

## What to extract

- Newly created tickets
- Status changes (especially to Done/Completed)
- Decisions captured in descriptions or comments
- Any ticket closed in the window (signals completed work not otherwise visible in git)

## What to skip

- Bot-generated or auto-updated tickets
- Tickets you are only a watcher on with no direct activity
