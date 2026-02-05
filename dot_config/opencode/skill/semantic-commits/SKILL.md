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

Priority order:
1. **Issue key** if available (e.g., `feat(PROJ-123): ...`)
2. **Component/area** (e.g., `fix(auth): ...`, `refactor(api): ...`)

## Description

- Lowercase, no period at end
- Imperative mood ("add" not "added")
- Focus on **why** not **what**
- Keep under 72 characters

## Examples

```
feat(PROJ-123): add password reset flow
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

## PR Descriptions

Keep minimal—no headers, just the essentials:
- 1-2 sentence summary of the change
- Link to issue (if applicable)
- Only add detail if something is non-obvious

Example:
```
Adds retry logic for flaky external API calls. Closes #123
```

Skip: bullet lists, `## Summary` headers, implementation details obvious from the diff.
