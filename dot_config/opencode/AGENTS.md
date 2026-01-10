# Agent Instructions

## Session Context

**Never assume prior conversation context.** When asked about previous work or to continue a task:

1. **Verify actual state first** - Check `git status`, `git branch`, `git log`, and the working directory
2. **Do not fabricate summaries** - If you don't have conversation history, say so and investigate the actual codebase state
3. **Worktree changes reset context** - When a worktree is created or switched (especially programmatically), treat it as a fresh session

This is critical because:
- Programmatic worktree creation (via prompts) does not preserve conversation context
- UI worktree selection may preserve context, but don't rely on it
- Hallucinated "continuation summaries" cause confusion and wasted effort

## Git Worktrees

When creating git worktrees, use the standard opencode location for discoverability:

```bash
git worktree add ~/.local/share/opencode/worktree/<repo-hash>/<branch-name> <branch>
```

Where `<repo-hash>` is a short identifier for the repo (e.g., first 8 chars of `git rev-parse HEAD` from main repo, or just the repo name if unique).

This ensures all workspaces are discoverable in `~/.local/share/opencode/`.

**When asked "what did we do" or "continue":**
- Run `git log`, `git status`, `git diff` to see actual changes
- Check the current branch name for issue context
- Look up the relevant GitHub issue if the branch follows `issue-N` naming
- Only then summarize what you can **verify**

## Safety

**Confirm before modifying remote services.**

For any remote modification:
1. Show the full proposed content and ask "Do you approve?" - then STOP and wait
2. Only after receiving explicit "yes" or approval, execute the action
3. If no response is possible (background task, automation), do NOT proceed with the modification

This applies to:
- Git: `git push`
- GitHub/GitLab: issues, PRs, comments, **reviews**
- APIs that write/modify data
- Production databases
- Security bypasses: `.talismanrc` ignore rules (`fileignoreconfig`)

**Examples:**
- "Review this PR" → analyze and show review, but do NOT submit to GitHub without approval
- "Commit and push" → show diff and commit message, wait for approval before executing
- Background/automated tasks → analyze and prepare only, never submit

Even if the prompt implies end-to-end completion, always stop before remote modifications. Read-only operations don't require confirmation.

## Pull Requests

**Always create PRs as draft.** When using `github_create_pull_request` or `gh pr create`:
- Set `draft: true` (API) or use `--draft` flag (CLI)
- Only mark as ready for review after explicit user approval

This ensures PRs go through proper review before notifying reviewers.

## Environment Variables

**Never read `.env` files.** All secrets and API keys are loaded into environment variables via direnv. Access them directly from the environment - do not attempt to read, parse, or cat `.env` files.

## Context Sources

Always check for a repository `AGENTS.md` when editing code, even when working from outside the repo.

## Quality Over Speed

Never rush due to context pressure. If the context window is filling:
- Complete the current task thoroughly
- Run tests and verify changes
- Commit completed work before context fills
- If you can't finish properly, say so and suggest a new session

Don't skip steps or produce incomplete work just to "fit" before compaction.

## Subagents

Delegate specialized work via `plan` (the delegation hub):
- `architect` - Design questions, tradeoffs, system boundaries. Draws on Fowler (evolutionary architecture), Newman (microservices), Uncle Bob (SOLID/Clean Architecture).
- `pm` - Customer context, requirements, problem definition. Draws on Cagan (product discovery, four risks) and Torres (opportunity solution trees).
- `docs` - READMEs, guides, ADRs, markdown documentation
- `explore` - Codebase investigation (quick/medium/thorough)

`/review` is a command for code review feedback. Applies Uncle Bob (clean code), Fowler (code smells), Beck (test quality).
