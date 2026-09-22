---
name: shipit
description: Load before committing and pushing a completed change
license: MIT
---

## Commit

- Verify the user-visible change before committing.
- Never commit with a failing required check.
- Never stage globally ignored files such as `.talismanrc`.
- Use Conventional Commit subjects: `type(scope): description`.
- Use `feat`, `fix`, `refactor`, `docs`, `test`, or `chore`.
- Use a semantic scope, not a ticket number.
- Write the description in imperative mood, lowercase, with no trailing period, under 72 characters.
- Include a `Co-Authored-By` trailer for the model that produced the change.
- Use the model provider domain in the trailer email, not the harness domain.

Example trailer:

```text
Co-Authored-By: openai-codex/gpt-5.6-sol <noreply@openai.com>
```

Before the first push, related local attempts can be squashed into one commit.
After review feedback, add commits instead of rewriting history.

## Push or deploy

- Show unpushed commits in chat first.
- State the branch name and one subject per line.
- Do not rerun the full suite during push unless a push-time check fails and needs a fix.
- Show the full remote-write payload before creating or updating a pull request, comment, or review.
- Never flip draft or ready state during a push.

For this dotfiles repository:

- Do not create a pull request.
- Ship with `chezmoi-deploy <branch>`.
- Keep deployment separate from the commit.

For repositories that use pull requests:

- Create one from the branch commits when none exists.
- Write the description in 1 or 2 sentences.
- Use `Resolves`, `Fixes`, or `Closes` for auto-close.
- Never reference private issue keys in public repositories.

## After push

- A push is not settled until required checks and automated review have landed or been ruled out.
- Use the repository's supported CI and review interfaces.
- Resolve base-branch conflicts before waiting for checks.
- If no checks exist on the current head, treat the pre-push suite as the gate.
- If checks fail, fix through the normal commit and push cycle.
- Match automated review against the current head.
- Resolve a review thread only after its fix is pushed.
