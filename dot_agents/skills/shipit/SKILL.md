---
name: shipit
description: Load before committing and pushing a completed change
license: MIT
---

## Shape the change

- Keep each pull request tiny and independently reviewable without splitting one coherent behavior across arbitrary layers.
- When related changes depend on one another, use `gh stack` for bottom-to-top branch order and stacked PR bases. Load `gh-stack` for stack operations and their hazards.
- One independent PR: use the normal GitHub workflow, not `gh stack`.
- This dotfiles repository is the exception: no PRs; deploy with `chezmoi-deploy <branch>`.

## Commit

- Do not commit with a failing required check.
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

- Show unpushed commits in chat first: branch name and one subject per line.
- Do not rerun the full suite during push unless a push-time check fails and needs a fix.
- Never flip draft or ready state during a push.

For repositories that use pull requests:

- Use `gh stack submit` for a dependent stack; follow `gh-stack` for PR state, branch, and remote-operation details.
- Keep each PR description to 1 or 2 sentences.
- Use `Resolves`, `Fixes`, or `Closes` for auto-close.
- Never reference private issue keys in public repositories.

For this dotfiles repository, keep deployment separate from the commit.

## After push

- A push is not settled until required checks and automated review have landed or been ruled out.
- Use the repository's supported CI and review interfaces.
- Resolve base-branch conflicts before waiting for checks.
- If no checks exist on the current head, treat the pre-push suite as the gate.
- If checks fail, fix through the normal commit and push cycle.
- Match automated review against the current head.
- Resolve a review thread only after its fix is pushed.
