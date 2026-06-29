---
name: gh
description: GitHub PRs, reviews, and issues
---

## Query recipe

### Discover orgs

Read GitHub orgs from chezmoi data:

```
chezmoi data --format json | jq -r '[.orgs | keys[]] | join(" ")'
```

If the result is empty, run without an org filter.

### Fetch activity

Use the `gh` skill to find the user's PRs and code reviews in the enrichment window:
- PRs authored by the authenticated user
- PRs where the user left a review

Use the `gh` skill to find issues opened or updated by the user in the window.

### Bot filter

Skip any actor matching `dependabot[bot]`. The real GitHub actor login includes the brackets — match `dependabot[bot]`, not plain `dependabot`.

## Triage rules

Skip:
- Automated dependency-bump PRs from `dependabot[bot]`
- Activity in archived repositories

Extract:
- PRs merged or closed during the window (title, repo, link)
- Review comments that capture decisions or design choices
- Issues closed or opened that represent significant project work
- Open review threads with outstanding action items assigned to the user

## Extraction rules

- For merged PRs, add a Status bullet to the relevant project profile if the work is significant; the write step handles repo-to-project mapping.
- For review decisions, anchor to the product/project and note the PR URL.
- For action items from open review threads, note the PR URL and thread for cross-reference at write time.
