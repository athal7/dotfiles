---
name: gh
description: GitHub PRs, reviews, and issues
---

Find, within the enrichment window: pull requests authored by the authenticated user, pull requests where the user left a review, and issues opened or updated by the user. Extract kb facts from the result.

### Discover eligible orgs

Read only GitHub organizations explicitly eligible for this KB:

```
chezmoi data --format json | jq -r '.orgs | to_entries[] | select(.value.kb_eligible == true) | .key'
```

If no organization is eligible, log `No GitHub organizations are KB-eligible` and skip this collector. Never fall back to an unscoped GitHub search.

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
