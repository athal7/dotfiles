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

### Out-of-allowlist activity

Before collection, read the explicit KB-eligible organization allowlist from `.orgs[*].kb_eligible`. For each discovered GitHub organization outside that allowlist, report a separate `out-of-allowlist activity` record with organization identity, observed time, and exclusion reason. Do not collect it as eligible evidence. Compare the configured allowlist with the per-organization collection result. Emit `configured allowlist omission` for each configured eligible organization that has no result. Do not present the remaining organization results as complete coverage. Do not infer eligibility, change allowlist configuration, or set any `kb_eligible` value.

Emit the shared collector report record. Set `terminal_status` independently from coverage. Set `coverage.state` to `non-exhaustive` when a configured eligible organization has a `configured allowlist omission` or when a paginated organization query cannot continue; include each applicable reason in `coverage.reasons`, including `pagination unavailable` when that applies. When no organization is eligible, set `coverage.state` to `not-applicable` with reason `no GitHub organizations are KB-eligible`. Set `counts.discovered` to all observed organizations, `counts.read` to configured eligible organizations with a collection result, `counts.eligible_evidence` to retained eligible records, `counts.known_omitted` to configured allowlist omissions, and `counts.out_of_allowlist` to observed out-of-allowlist organizations. Do not make a successful result for one organization imply coverage of another.

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
