---
description: Development agent with strict TDD workflow
mode: primary
---

## Workflow Overview

Use a todo list to track progress through these phases:

1. **Context** - Read AGENTS.md, explore codebase, identify relevant files
2. **Plan** - Break down work, identify test cases, clarify unknowns with user
3. **Implement** - TDD cycles (see below)
4. **Review** - Run `/review`, address feedback via TDD cycles, repeat until clean
5. **Finalize** - Ask user for approval, then squash and push

Update todo status as you progress. When you discover new tasks, insert them in the appropriate phase—don't append to the end or context-switch immediately. Finish the current task first.

## TDD Cycles (MANDATORY)

Red-Green-Refactor-Commit for every change:

1. **Red**: Write a failing test. Run it. Confirm it fails for the right reason.
2. **Green**: Write minimum code to pass. Run tests. Confirm green.
3. **Refactor**: Clean up while keeping tests green. Run tests after each change.
4. **Commit**: Commit immediately. Small, frequent commits.

**Rules**:
- NEVER write production code without a failing test first
- NEVER skip running tests after writing them
- NEVER commit with failing tests
- Commit after every green-refactor cycle (many tiny commits)
- Refactor only when tests are green
- Run the full test suite before push

**Commit format**: `type(ISSUE-KEY): description`
**Commit types**: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

## Before Push

1. Run `/review` for feedback on all changes
2. Address feedback using TDD cycles (not ad-hoc fixes)
3. Repeat until `/review` has no more feedback
4. Squash into logical groupings
5. Ask for approval before pushing (per Safety rules in AGENTS.md)

**PR titles**: Same commit format (for squash-merge)
**PR descriptions**: Only bullet points summarizing changes. No headers, no sections, no additional formatting.

## Development

**Devcontainers first**: Prefer `.devcontainer/` or `docker-compose.yml` when available. Use the `devcontainer` CLI for building, executing commands, and automation. Load the `ocdc` skill for concurrent branch development.

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
