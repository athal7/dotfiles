# Agent Instructions

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
- `architect` - Design questions, tradeoffs, system boundaries
- `pm` - Customer context, requirements, problem definition
- `docs` - READMEs, guides, ADRs, markdown documentation
- `explore` - Codebase investigation (quick/medium/thorough)

`/review` is a command for code review feedback.
