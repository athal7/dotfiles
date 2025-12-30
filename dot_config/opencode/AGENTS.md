# Agent Instructions

## Safety

**Confirm before modifying remote services.**

For any remote modification:
1. Show the full proposed content and ask "Do you approve?" - then STOP and wait
2. Only after receiving explicit "yes" or approval, execute the action
3. If no response is possible (background task, automation), do NOT proceed with the modification

This applies to:
- Git: `git push`, final commits (not WIP amends - see Git Workflow below)
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
- Use WIP commits to protect in-flight work (see Git Workflow)
- If you can't finish properly, say so and suggest a new session

Don't skip steps or produce incomplete work just to "fit" before compaction.

## Development

**Devcontainers first**: Prefer `.devcontainer/` or `docker-compose.yml` when available. Use the `devcontainer` CLI for building, executing commands, and automation.

**Clarify before implementing**: For UI features, confirm placement, behavior, and user flow. Ask about edge cases (empty states, errors, permissions) and verify which repo/service the work belongs in.

**Secrets**: Check `~/AGENTS_LOCAL.md` for your configured secrets manager.

## Git Workflow

### WIP Commits (No Approval Needed)

Protect in-flight work by continuously amending a WIP commit. This prevents losing changes to context compaction or session interruption.

**During development:**
1. After tests pass, immediately stage all changes and amend to the WIP commit
2. Use message: `wip: <brief description of current state>`
3. Do this automatically after every green test run - no approval needed
4. WIP amends are local-only safety saves, not meaningful commits

### Final Commit (Approval Required)

When work is complete:
1. Ask: "Ready to finalize. What should the commit message be?"
2. Show the full diff of all accumulated changes
3. Wait for user to provide the final message
4. Amend with proper format: `type(ISSUE-KEY): description`
5. Offer code review via `review` subagent before finalizing
6. Ask for push approval per normal safety rules

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

**Testing**: Write tests first when practical. Prefer integration tests. Cover happy path, edge cases, and errors.

**Backwards compatibility**: When modifying shared components, check all callers first.

## Subagents

Delegate specialized work:
- `architect` - Design questions, tradeoffs, system boundaries
- `review` - Code review feedback on PRs or changes
- `pm` - Writing issues, project specs, documentation
