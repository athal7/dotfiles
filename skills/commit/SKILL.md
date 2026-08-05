---
name: commit
description: Semantic commit format and pre-commit checks
license: MIT
---

Verify the diff and apply any findings before you stage. Run git from the worktree you're committing in. Then:

1. `git add -A`
2. Unstage in-flight OpenSpec change files — review artifacts, not code; they reach the durable store at archive time:
   ```
   git reset -q -- 'openspec/changes/*' ':(exclude)openspec/changes/archive'
   ```
3. `git check-ignore <files>` — never stage globally-ignored files (`~/.config/git/ignore`, e.g. `.talismanrc`).
4. Run the full test suite — unit, integration, e2e, system. No commits with failures. This is the gate; push assumes it already ran.
5. Draft the message, with a trailer naming the model:
   ```
   Co-Authored-By: anthropic/claude-sonnet-4-6 <noreply@opencode.ai>
   ```

## Format

`type(scope): description`

| Type | When |
|------|------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Neither fixes nor adds |
| `docs` | Documentation only |
| `test` | Adding or updating tests |
| `chore` | Build, CI, dependencies, tooling |

Scope is a component/area, semantic — not a ticket number. Description: lowercase, imperative, no trailing period, under 72 chars, says *why*.

## Squashing

**Before first push** — squash related commits: several attempts at one feature → one `feat`; fix plus its test → one `fix`. Unrelated changes stay separate.

**After review feedback** — add commits, never rewrite history; reviewers lose context. Squash-and-merge happens at the platform.
