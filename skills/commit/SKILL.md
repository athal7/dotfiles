---
name: commit
description: Semantic commit format and pre-commit checks
license: MIT
---

## STOP — verification gate

**Before reading further, confirm in this session you have:**

1. Verified the staged diff.
2. Applied any findings.
3. Re-verified until clean.

**If any of those is missing, stop now and verify first.** A 30-day audit found 60% of commit-time sessions skipped this step despite the precondition being declared. The pattern is the agent skipping past preamble — this gate exists to interrupt that. Do not draft the commit message, do not run `git add`, do not continue past this section until verification has happened.

## Before every commit

Run automatically without asking. **Set the bash tool's `workdir` to the repo root rather than passing `git -C <path>`.** Permission patterns like `git push *` match parsed argv starting with `git push`; `git -C <path> push` injects flags between `git` and the subcommand and bypasses those patterns silently.

1. **Stage**: `git add -A`.
2. **Skip globally-ignored files**: `git check-ignore <files>`. Do NOT stage files in `~/.config/git/ignore` (e.g. `.talismanrc`).
3. **Run the full test suite** — unit, integration, e2e, system. Do not commit with failures.
4. **Draft the commit message** in the format below, with a `Co-Authored-By` trailer naming the model used (e.g. `anthropic/claude-sonnet-4-6`):
   ```
   Co-Authored-By: anthropic/claude-sonnet-4-6 <noreply@opencode.ai>
   ```

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
