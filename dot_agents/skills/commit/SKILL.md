---
name: commit
description: Semantic commit format and pre-commit checks
license: MIT
---


- Verify the user-visible change before committing.
- Never commit with a failing required check.
- Never stage globally ignored files such as `.talismanrc`.
- Keep deploy separate from commit.
- Use Conventional Commit subjects: `type(scope): description`.
- Use `feat`, `fix`, `refactor`, `docs`, `test`, or `chore`.
- Use a semantic scope, not a ticket number.
- Write the description in imperative mood, lowercase, no trailing period, and under 72 characters.
- Include a `Co-Authored-By` trailer for the model that produced the change.
- Use the model provider domain in the trailer email, not the harness domain.

Example trailer:

```text
Co-Authored-By: openai-codex/gpt-5.6-sol <noreply@openai.com>
```

Before first push, related local attempts can be squashed into one commit.
After review feedback, add commits instead of rewriting history.
