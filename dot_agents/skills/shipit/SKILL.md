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
- Create PRs as drafts (`draft: true` with the official GitHub MCP; `gh stack submit --auto` for a stack). Never use `--open` to bypass the review gate.
- Keep each PR draft until all requested and required human reviewers have approved and every configured review bot has submitted GitHub `APPROVED` or produced a repository-documented, head-specific clean-result signal. Pending reviews, change requests, stale or dismissed approvals, and unresolved findings block readiness; a generic green CI check alone is not review approval.
- Keep each PR description to 1 or 2 sentences.
- Use `Resolves`, `Fixes`, or `Closes` for auto-close.
- Never reference private issue keys in public repositories.

For this dotfiles repository, keep deployment separate from the commit.

## After push

- A push is not settled until required checks and all configured automated reviews have completed successfully, or repository evidence establishes that none are configured.
- Discover review bots from repository configuration, `.github/workflows/`, and recent PR review/check authors; verify each bot's supported request or trigger mechanism rather than assuming one provider or command.
- Explicitly request or trigger each configured bot's review for the PR; verify it actually starts against the current head. Do not duplicate an already-running review for that head.
- If a bot says it only runs on ready PRs, check its comment, repository instructions, workflow, and recent PRs for a draft-compatible command or override (often a specific PR comment); use that supported trigger and verify it starts on the current head. If no override exists, keep the PR draft and report the blocker; never mark ready merely to trigger review.
- Use the repository's supported CI and review interfaces.
- Resolve base-branch conflicts before waiting for checks.
- If no checks exist on the current head, treat the pre-push suite as the gate.
- If checks fail, fix through the normal commit and push cycle.
- Verify each automated review result—including any documented clean-result signal—applies to the current head.
- After new commits, re-request affected reviews; do not count stale results as approval.
- Resolve a review thread only after its fix is pushed.
- Recheck all review approvals, findings, and required checks immediately before marking ready. Make that a separate post-review action, never part of the push.
