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
