---
name: commit
description: Semantic commit format and pre-commit checks
license: MIT
---

Verify the diff and apply any findings before you stage. Then:

1. `git add -A`
2. `git check-ignore <files>` — never stage globally-ignored files (`~/.config/git/ignore`, e.g. `.talismanrc`).
3. Run the full test suite — unit, integration, e2e, system. No commits with failures. This is the gate; push assumes it already ran.
4. Draft the message, with a trailer naming the model actually running the session — email is the model's provider domain, never the harness (`omp.sh`, …):
   ```
   Co-Authored-By: mlx/default_model <noreply@mlx.local>
   ```
   Swap in the current model and its provider's domain (`openai.com`, `google.com`, `x.ai`, …) — don't reuse a stale example verbatim.

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
