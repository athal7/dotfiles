---
name: gh
description: GitHub PRs, reviews, and issues
---

Dispatch the `github` subagent (`task` tool, `subagent_type: github`) with a prompt asking it to find, within the enrichment window: pull requests authored by the authenticated user, pull requests where the user left a review, and issues opened or updated by the user. Extract kb facts from its returned summary.

### Discover orgs

Read GitHub orgs from chezmoi data:

```
chezmoi data --format json | jq -r '[.orgs | keys[]] | join(" ")'
```

If the result is empty, ask the subagent to search without an org filter.

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
