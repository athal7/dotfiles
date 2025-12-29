# Agent Instructions

## Safety

**Confirm before modifying remote services.**

For any remote modification:
1. Show the full proposed content and ask "Do you approve?" - then STOP
2. Only after explicit approval, execute the action

This applies to:
- Git: `git push`, `git commit`
- GitHub/GitLab: issues, PRs, comments
- APIs that write/modify data
- Production databases

Even if the user says "commit and push", show the proposed content first and wait for confirmation. Read-only operations don't require confirmation.

## Context Sources

1. **`~/AGENTS_LOCAL.md`** - Machine-specific: tool names, repos, infrastructure, secrets
2. **Repository `AGENTS.md`** - Project-specific: linting, testing, patterns

Always check for a repository `AGENTS.md` when editing code, even when working from outside the repo.

## Quality Over Speed

Never rush due to context pressure. If the context window is filling:
- Complete the current task thoroughly
- Run tests and verify changes
- If you can't finish properly, say so and suggest a new session

Don't skip steps or produce incomplete work just to "fit" before compaction.

## Development

**Devcontainers first**: Prefer `.devcontainer/` or `docker-compose.yml` when available. Use the `devcontainer` CLI for building, executing commands, and automation.

**Clarify before implementing**: For UI features, confirm placement, behavior, and user flow. Ask about edge cases (empty states, errors, permissions) and verify which repo/service the work belongs in.

**Secrets**: Check `~/AGENTS_LOCAL.md` for your configured secrets manager.

## Git

**Worktrees**: Use `worktree-setup` skill for feature branches. For projects with `.devcontainer/`, also use `devcontainer-ports` skill for unique ports.

**Commits**: `type(ISSUE-KEY): description`
- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
- PR titles use same format (for squash-merge)

**Post-push**: Offer to clean up worktree (`git worktree remove <path>`)

## Code Quality

- Follow project conventions (check linter/formatter configs)
- Self-documenting code; comments only for "why" not "what"
- Remove dead code, debug logging, unused methods
- Fail loudly over silent error handling
- Defer DB writes until user explicitly confirms
- Question defensive checks that can never fail
- Use precise naming; avoid overloaded terms

**Testing**: Write tests first when practical. Prefer integration tests. Cover happy path, edge cases, and errors.

**Backwards compatibility**: When modifying shared components, check all callers first.

## Pre-Commit

Before committing, consider offering:
1. **Code review** - Delegate to `review` subagent for security/performance/quality feedback
2. **Screencast demo** - Run `/screencast` to record a demo of the changes

## Subagents

Delegate specialized work:
- `review` - Code review feedback on PRs or changes
- `pm` - Writing issues, project specs, documentation
