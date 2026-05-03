---
name: issues
description: Route issue management to the right tracker based on GitHub org — Linear for work, GitHub Issues for OSS and personal repos
license: MIT
compatibility: opencode
metadata:
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
3. Look up the org in agent config (`orgs.<org>.issues`).
4. If the value is `"linear"` → use the `linear-cli` skill.
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

## Templates

Both trackers have templates configured outside this skill. Read the relevant one before authoring an issue, project, or status update so the artifact matches the established shape; don't invent your own structure.

**Linear:** templates are configured in the workspace and applied automatically in the web UI. The CLI doesn't apply them — fetch the template content and follow it manually:

```bash
# List templates available to you
linear api '{ templates { id name type team { key } } }'

# Get the content of a specific template
linear api --variable id=TEMPLATE_UUID '{ template(id: $id) { name templateData } }'
```

**GitHub:** templates live in the repo at `.github/ISSUE_TEMPLATE/*.md` and `.github/pull_request_template.md`. `gh issue create --template <name>` only works in interactive mode; for non-interactive use, read the template file directly and pass content via `--body-file`.
