---
name: issues
description: Route issue management to the right tracker based on GitHub org — Linear for work, GitHub Issues for OSS and personal repos
provides:
  - issues
---

# Issues

Route to the correct issue tracker based on the GitHub remote org.

## Routing

1. Get the GitHub org from the current repo:
   ```bash
   git remote get-url origin
   ```
2. Parse the org from the URL (works for both HTTPS and SSH remotes).
3. Run `chezmoi data --format json` and read `.linear_orgs` — a list of GitHub orgs that use Linear.
4. If the repo org is in `.linear_orgs` → use the `linear-cli` skill.
5. Otherwise → use `gh issue` commands.
6. If there is no git remote, ask the user which tracker to use.

## Linear: Project Body

The project body (inline editor in the UI) is the `documentContent.content` field — not the legacy `description` field. Read it via:

```bash
linear api '{ project(id: "PROJECT_UUID") { documentContent { content } } }'
```

Write it via `projectUpdate` with the `content` field — the UI may need a hard refresh to show the update:

```bash
linear api --variable projectId=PROJECT_UUID --variable content=@/tmp/content.md << 'GRAPHQL'
mutation($projectId: String!, $content: String!) {
  projectUpdate(id: $projectId, input: { content: $content }) {
    success
  }
}
GRAPHQL
```

Note: `linear document create --project` creates an *attached* document (Documents tab), not the inline body. `linear document update --content-file` is broken (schpet/linear-cli#153).
