---
name: commit
description: Semantic commit format and pre-commit checks
license: MIT
metadata:
  provides:
    - commit
  requires:
    - verify
---

**Precondition:** verification must have happened first — use your `verify` capability, apply findings, re-verify until clean. Do not load `commit` on an unverified diff.

## Before every commit

Run automatically without asking:

1. **Stage**: `git add -A`.
2. **Skip globally-ignored files**: `git check-ignore <files>`. Do NOT stage files in `~/.config/git/ignore` (e.g. `.talismanrc`, `.opencode/context-log.md`).
3. **Run the full test suite** — unit, integration, e2e, system. Do not commit with failures.
4. **Draft the commit message** in the format below, with a `Co-Authored-By` trailer naming the model used (e.g. `anthropic/claude-sonnet-4-6`):
   ```
   Co-Authored-By: anthropic/claude-sonnet-4-6 <noreply@opencode.ai>
   ```
5. **Present and STOP.** Show what was implemented and the drafted message. End your response and wait for explicit approval — *unless* the user already said "ship it"/"push"/"commit and push", in which case that command is the approval; skip directly to the commit.

## Format

```
type(scope): description
```

| Type | When |
|------|------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes nor adds |
| `docs` | Documentation only |
| `test` | Adding or updating tests |
| `chore` | Build, CI, dependencies, tooling |

**Scope** — component/area (`fix(auth): ...`). Semantic, not ticket numbers.

**Description** — lowercase, no trailing period, imperative ("add" not "added"), focus on *why*, under 72 characters.

```
feat(auth): add password reset flow
fix(auth): prevent token refresh race condition
refactor(api): extract validation middleware
chore(deps): bump lodash to 4.17.21
```

## Squashing

**Before first push:** squash related commits — multiple feature attempts → single `feat`, fix+test for same issue → single `fix`. Keep unrelated changes separate.

**After review feedback:** add new commits, don't rewrite history. Each round gets its own commit(s) with an appropriate type (e.g. `fix(auth): address review — validate token expiry`). Never force-push pushed commits — reviewers lose context. Squashing at merge happens via the platform's squash-and-merge.
