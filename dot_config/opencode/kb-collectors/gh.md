---
name: gh
enabled: true
priority: 4
authoritative_for: [shipped-code, reviews]
description: GitHub PRs you authored or reviewed in the enrichment window
# orgs: GitHub orgs to scope searches to. When set, each org is added as
# `org:NAME` to the search query. Leave empty for no org filter (searches
# across all repos you have access to).
orgs: []
# skip_bots: commit authors / PR actors to ignore
skip_bots: [dependabot]
---

## How to query

Scope to the orgs listed in `orgs` frontmatter. Build the org filter by joining each as `org:NAME`:

```bash
# PRs you opened or updated (add org filters if orgs list is non-empty)
gh search prs --author "@me" --state all --updated ">=YYYY-MM-DD" \
  --json number,title,repository,state,updatedAt,body

# PRs you were asked to review
gh search prs --review-requested "@me" --updated ">=YYYY-MM-DD" \
  --json number,title,repository,state,updatedAt
```

If the `orgs` list in frontmatter is empty, omit the org filter and search across all repos.

## What to extract

- Merged PRs — what shipped
- Review comments that surfaced decisions
- Linked issues

## What to skip

- Draft PRs
- Commits and PRs authored by bots listed in `skip_bots`
