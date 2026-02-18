---
name: semantic-commits
description: Semantic commit format and squashing guidance
---

## Format

```
type(scope): description
```

## Types

| Type | When to use |
|------|-------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes nor adds |
| `docs` | Documentation only |
| `test` | Adding or updating tests |
| `chore` | Build, CI, dependencies, tooling |

## Scope

Always use **component/area** (e.g., `fix(auth): ...`, `refactor(api): ...`). Keep scope semantic — don't use ticket numbers as scope.

## Description

- Lowercase, no period at end
- Imperative mood ("add" not "added")
- Focus on **why** not **what**
- Keep under 72 characters

## Examples

```
feat(auth): add password reset flow
fix(auth): prevent token refresh race condition
refactor(api): extract validation middleware
test(user): add edge cases for email validation
chore(deps): bump lodash to 4.17.21
```

## Squashing

Before push, squash related commits:
- Multiple attempts at same feature → single `feat`
- Fix + test for same issue → single `fix`
- Keep logical separation (don't squash unrelated changes)

## Branch Names

**Before pushing**, check if the branch name is meaningful. Auto-generated worktree branches (e.g., `opencode/cosmic-wizard`) should be renamed to reflect the change:
```bash
[[ "$(git branch --show-current)" =~ ^opencode/ ]] && git branch -m "$(git branch --show-current)" <new-name>
```

**Naming convention**: `<type>/<short-description>` — type matches the commit type, description is 2-4 kebab-case words (e.g., `feat/add-auth-middleware`, `fix/token-refresh-race`).

## PR Descriptions

Keep minimal—no headers, just the essentials:
- 1-2 sentence summary of the change
- Only add detail if something is non-obvious
- Link to the issue when the issue tracker is visible to the repo's audience (e.g., `Closes #123` for GitHub issues, `Closes PROJ-123` for private repos)
- **Never reference internal/private issue keys** (e.g., Linear) in public repos

Example:
```
Adds retry logic for flaky external API calls. Closes #123
```

Skip: bullet lists, `## Summary` headers, implementation details obvious from the diff.

## Issue Traceability

When the issue tracker is internal (e.g., Linear) and the repo is public, don't reference issues in commits or PRs. Instead, update the Linear issue with a link to the PR.

Check repo visibility with: `gh repo view --json visibility -q '.visibility'`
