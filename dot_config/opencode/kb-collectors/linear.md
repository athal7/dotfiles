---
name: linear
enabled: true
priority: 3
authoritative_for: [tickets, completed-work]
description: Linear issues you touched in the enrichment window
# workspace: the Linear workspace slug passed to the `linear` CLI.
# Leave empty to use whatever workspace the CLI is already authenticated to.
workspace: ""
---

## How to query

If `workspace` is set in frontmatter, pass it with `--workspace`:

```bash
linear issue mine --updated-after YYYY-MM-DD --all-states --no-pager
# (the CLI uses the default workspace; --workspace flag is not supported by the
#  current linear CLI — workspace selection is via `linear auth` at setup time)
```

The workspace this collector targets is `{{ frontmatter.workspace }}` (set in frontmatter; update there if you switch orgs).

## What to extract

- Newly created tickets
- Status changes
- Decisions captured in descriptions or comments
- Any ticket closed in the window (signals completed work not otherwise visible in git)

## What to skip

- Bot-generated or auto-updated tickets
- Tickets you are only a watcher on with no direct activity
