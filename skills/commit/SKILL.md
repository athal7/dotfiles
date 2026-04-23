---
name: commit
description: Semantic commit format, branch naming, squashing guidance, and post-commit learning capture
license: MIT
metadata:
  provides:
    - commit
  requires:
    - agent
    - verify
---

## Before Every Commit

Run steps 1–5 automatically — do not ask the user before starting:

1. **Stage all changes**: `git add -A`
2. **Check for globally-ignored files**: `git check-ignore <files>` — do NOT stage files in `~/.config/git/ignore`. Key examples: `.talismanrc`, `.opencode/context-log.md`.
3. **Run the full test suite** — unit, integration, e2e, and system tests. Do not commit with failing tests.
4. **Verify the diff** — use your `verify` capability. If the verdict is anything other than approve, apply the findings and re-verify until the verdict is clean. Do not wait for user input between iterations.
5. **Draft the commit message** — format below, including a `Co-Authored-By` trailer identifying the specific model used in this session (e.g. `anthropic/claude-sonnet-4-6`):
   ```
   Co-Authored-By: anthropic/claude-sonnet-4-6 <noreply@opencode.ai>
   ```
6. **Present and STOP** — show a summary of what was implemented, the final verify verdict, and the drafted commit message. **End your response.** Wait for explicit approval before creating the commit.
   - **Exception:** if this commit is part of a user-initiated ship/push flow (user said "ship it", "push", "commit and push", etc.), that command is the approval for both the commit and the push. Skip step 6 and proceed directly to step 7.
7. **Commit** — after approval (or under the ship-flow exception), create the commit with the drafted message.

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

**Before first push**, squash related commits:
- Multiple attempts at same feature → single `feat`
- Fix + test for same issue → single `fix`
- Keep logical separation (don't squash unrelated changes)

**After review feedback**, add new commits instead of rewriting history:
- Each round of feedback gets its own commit(s)
- Use the appropriate type for the change (e.g., `fix(auth): address review — validate token expiry`)
- Do NOT force-push to rewrite already-pushed commits — reviewers lose context
- Squashing happens at merge time (via the platform's squash-and-merge)

## Branch Names

**Before pushing**, check if the branch name is meaningful. Auto-generated worktree branches (e.g., `opencode/cosmic-wizard`) should be renamed to reflect the change. Use your `branching` capability to rename if needed.

**Naming convention**: `<type>/<short-description>` — type matches the commit type, description is 2-4 kebab-case words (e.g., `feat/add-auth-middleware`, `fix/token-refresh-race`).

## Merge Request Descriptions

Keep minimal — no headers, just the essentials:
- 1-2 sentence summary of the change
- Only add detail if something is non-obvious
- Link to the issue when the issue tracker is visible to the repo's audience (e.g., `Closes #123`)
- **Never reference internal/private issue keys** in public repos

Example:
```
Adds retry logic for flaky external API calls. Closes #123
```

Skip: bullet lists, `## Summary` headers, implementation details obvious from the diff.

## Issue Traceability

When the issue tracker is internal and the repo is public, don't reference issues in commits or merge requests. Instead, update the issue with a link to the merge request via your `issues` capability.

Check repo visibility via your `source-control` capability.
