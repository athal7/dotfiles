---
name: gh
priority: 4
authoritative_for: [shipped-code, reviews]
description: GitHub PRs you authored or reviewed in the enrichment window
# skip_bots: commit authors / PR actors to ignore
skip_bots: [dependabot]
---

## Enabled check

Read GitHub orgs from chezmoi data:

```bash
ORGS=$(chezmoi data --format json | jq -r '[.orgs | keys[]] | join(" ")')
```

If `ORGS` is empty, search across all repos you have access to (no org filter). If non-empty, scope searches with an `org:NAME` filter per org.

## How to query

```bash
# PRs you opened or updated
gh search prs --author "@me" --state all --updated ">=YYYY-MM-DD" \
  --json number,title,repository,state,updatedAt,body

# PRs you were asked to review
gh search prs --review-requested "@me" --updated ">=YYYY-MM-DD" \
  --json number,title,repository,state,updatedAt
```

Add `org:NAME` to each query for every org in `ORGS` (run one query per org, or combine with multiple `org:` terms in a single search string).

## What to extract

- Merged PRs — what shipped
- Review comments that surfaced decisions
- Linked issues

## What to skip

- Draft PRs
- Commits and PRs authored by bots listed in `skip_bots`
