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

**Examples:**
- "Review this PR" → analyze and show review, but do NOT submit to GitHub without approval
- "Commit and push" → show diff and commit message, wait for approval before executing
- Background/automated tasks → analyze and prepare only, never submit

Even if the prompt implies end-to-end completion, always stop before remote modifications. Read-only operations don't require confirmation.

## Context Sources

1. **`~/AGENTS_LOCAL.md`** - Machine-specific: tool names, repos, infrastructure, secrets
2. **Repository `AGENTS.md`** - Project-specific: linting, testing, patterns

Always check for a repository `AGENTS.md` when editing code, even when working from outside the repo.

## Quality Over Speed

Never rush due to context pressure. If the context window is filling:
- Complete the current task thoroughly
- Run tests and verify changes
- Commit completed work before context fills
- If you can't finish properly, say so and suggest a new session

Don't skip steps or produce incomplete work just to "fit" before compaction.

## Development

**Devcontainers first**: Prefer `.devcontainer/` or `docker-compose.yml` when available. Use the `devcontainer` CLI for building, executing commands, and automation.

**Clarify before implementing**: For UI features, confirm placement, behavior, and user flow. Ask about edge cases (empty states, errors, permissions) and verify which repo/service the work belongs in.

**Secrets**: Check `~/AGENTS_LOCAL.md` for your configured secrets manager.

## Plan Agent

**Delegate design decisions to `architect`**. Before proposing implementation approaches:
- Use `architect` for any non-trivial design question
- Use `architect` when there are multiple viable approaches
- Use `architect` when changes affect system boundaries or module structure
- Use `architect` to validate tradeoffs before committing to a direction

Don't skip architectural review to save time. Poor design decisions are expensive to fix.

## Build Agent

**Strict Red-Green-Refactor-Commit workflow**. Every change follows TDD:

1. **Red**: Write a failing test first. Run it. Confirm it fails for the right reason.
2. **Green**: Write the minimum code to make the test pass. Run tests. Confirm green.
3. **Refactor**: Clean up the code while keeping tests green. Run tests after each change.
4. **Commit**: Commit immediately. Small, frequent commits.

**Rules**:
- Never write production code without a failing test
- Never commit with failing tests
- Commit after every green-refactor cycle (many tiny commits)
- Refactor only when tests are green
- Run the full test suite before push

**Before push**: Squash into logical groupings (not necessarily one commit). Ask for approval before pushing (per Safety rules).

**Commit format**: `type(ISSUE-KEY): description`
**Commit types**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
**PR titles**: Use same format (for squash-merge)

### Worktrees

Use `devcontainer-worktrees` skill for concurrent branch development. For devcontainer projects, use clone-based isolation instead of git worktrees.

**Post-push**: Offer to clean up worktree (`git worktree remove <path>`)

## Code Quality

- Follow project conventions (check linter/formatter configs)
- Self-documenting code; comments only for "why" not "what"
- Remove dead code, debug logging, unused methods
- Fail loudly over silent error handling
- Defer DB writes until user explicitly confirms
- Question defensive checks that can never fail
- Use precise naming; avoid overloaded terms

**Backwards compatibility**: When modifying shared components, check all callers first.

## Subagents

Delegate specialized work:
- `architect` - Design questions, tradeoffs, system boundaries
- `review` - Code review feedback on PRs or changes
- `pm` - Writing issues, project specs, documentation
