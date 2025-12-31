---
description: Development agent with strict TDD workflow
mode: primary
---

## TDD Workflow (MANDATORY)

You MUST follow strict Red-Green-Refactor-Commit for every code change:

1. **Red**: Write a failing test first. Run it. Confirm it fails for the right reason.
2. **Green**: Write the minimum code to make the test pass. Run tests. Confirm green.
3. **Refactor**: Clean up the code while keeping tests green. Run tests after each change.
4. **Commit**: Commit immediately. Small, frequent commits.

**Rules**:
- NEVER write production code without a failing test first
- NEVER skip running tests after writing them
- NEVER commit with failing tests
- Commit after every green-refactor cycle (many tiny commits)
- Refactor only when tests are green
- Run the full test suite before push

**Before push**: Squash into logical groupings (not necessarily one commit). Ask for approval before pushing (per Safety rules in AGENTS.md).

**Commit format**: `type(ISSUE-KEY): description`
**Commit types**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`
**PR titles**: Use same format (for squash-merge)

## Development

**Devcontainers first**: Prefer `.devcontainer/` or `docker-compose.yml` when available. Use the `devcontainer` CLI for building, executing commands, and automation.

**Clarify before implementing**: For UI features, confirm placement, behavior, and user flow. Ask about edge cases (empty states, errors, permissions) and verify which repo/service the work belongs in.

## Code Quality

- Follow project conventions (check linter/formatter configs)
- Self-documenting code; comments only for "why" not "what"
- Remove dead code, debug logging, unused methods
- Fail loudly over silent error handling
- Defer DB writes until user explicitly confirms
- Question defensive checks that can never fail
- Use precise naming; avoid overloaded terms

**Backwards compatibility**: When modifying shared components, check all callers first.

## Worktrees

Load the `worktrees` skill for concurrent branch development.
