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
- Approval prompts follow person-visibility: creating and pushing a draft, and updating its branch, run unattended, while marking ready, commenting, requesting review, and merging prompt.

For repositories that use pull requests:

- Use `gh stack submit` for a dependent stack; follow `gh-stack` for PR state, branch, and remote-operation details.
- Create PRs as drafts (`draft: true` with the official GitHub MCP; `gh stack submit --auto` for a stack). Never use `--open` to bypass readiness checks.
- Keep each PR draft until implementation and required checks are complete, findings are resolved, and every configured review bot that can run on drafts has submitted GitHub `APPROVED` or produced a repository-documented, head-specific clean-result signal. A generic green CI check alone is not review approval.
- Then mark the PR ready (`draft: false`) in a separate action before requesting or waiting for human review. Never wait for human approval while the PR is draft.
- Human approval gates merging, not readiness. Before merging, all requested and required human reviewers must have approved and every configured review bot must have a current-head approval or documented clean-result signal; pending reviews, change requests, stale or dismissed approvals, and unresolved findings block merge.
- Keep each PR description to 1 or 2 sentences.
- Use `Resolves`, `Fixes`, or `Closes` for auto-close.
- Never reference private issue keys in public repositories.

For this dotfiles repository, keep deployment separate from the commit.

## After push

- A push is not settled until required checks and all configured automated reviews have completed successfully, or repository evidence establishes that none are configured.
- Discover review bots from repository configuration, `.github/workflows/`, and recent PR review/check authors; verify each bot's supported request or trigger mechanism rather than assuming one provider or command.
- Explicitly request or trigger each configured bot's review for the PR; verify it actually starts against the current head. Do not duplicate an already-running review for that head.
- If a bot says it only runs on ready PRs, check its comment, repository instructions, workflow, and recent PRs for a draft-compatible command or override (often a specific PR comment); use that supported trigger and verify it starts on the current head. If no override exists, mark the PR ready once the other readiness gates are met, then trigger the bot and verify its current-head result before merging.
- Use the repository's supported CI and review interfaces.
- Resolve base-branch conflicts before waiting for checks.
- Turn on Agent Merge ("Watch and fix" in the merge box, or for all PRs in Copilot settings) by default when you open a PR: it clears failing workflows and base conflicts without a polling loop, so prefer it over babysitting checks or waiting for a reviewer to report red CI. It pushes to this branch, so check commit authors before diagnosing a failure it may already be fixing, fetch before pushing so you do not fight its commits, and review what it pushed as you would a contributor's. Enabling auto-merge or letting Copilot approve in your place is a separate decision: those change who acts on the branch.
- If no checks exist on the current head, treat the pre-push suite as the gate.
- If checks fail, fix through the normal commit and push cycle.
- Verify each automated review result—including any documented clean-result signal—applies to the current head.
- After new commits, re-request affected reviews; do not count stale results as approval.
- Resolve a review thread only after its fix is pushed.
- Recheck readiness gates on the current head immediately before marking ready, separately from the push. Recheck all review approvals, findings, and required checks immediately before merging.
