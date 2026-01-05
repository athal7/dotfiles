---
description: Review changes [commit|branch|pr], defaults to uncommitted
subtask: true
---

Input: $ARGUMENTS

## Workspace Detection

Before reviewing, determine the correct workspace directory:

1. **Check for active devcontainer context** - Use the `devcontainer` tool (no arguments) to check if a devcontainer is targeted
   - If active, use the workspace path from the output for all file operations
2. **Otherwise** - Use the current working directory

When a workspace is detected, use it as the base path for:
- Reading files (AGENTS.md, source files)
- Git operations (use `--git-dir` and `--work-tree` or `cd` to workspace first)

## Determining What to Review

Based on the input provided, determine which type of review to perform:

1. **No arguments (default)**: Review all uncommitted changes
   - Run: `git diff` for unstaged changes
   - Run: `git diff --cached` for staged changes

2. **Commit hash** (40-char SHA or short hash): Review that specific commit
   - Run: `git show $ARGUMENTS`

3. **Branch name**: Compare current branch to the specified branch
   - Run: `git diff $ARGUMENTS...HEAD`

4. **PR URL or number** (contains "github.com" or "pull" or looks like a PR number): Review the pull request
   - Run: `gh pr view $ARGUMENTS` to get PR context
   - Run: `gh pr diff $ARGUMENTS` to get the diff

## Gathering Context

**Diffs alone are not enough.** After getting the diff, read the entire file(s) being modified to understand the full context. Code that looks wrong in isolation may be correct given surrounding logic—and vice versa.

- Use the diff to identify which files changed
- Read the full file to understand existing patterns, control flow, and error handling
- Check for existing conventions files (CONVENTIONS.md, AGENTS.md, .editorconfig, etc.) **in the detected workspace directory**

## Style

- Use "I" statements: "If it were me...", "I wonder if..."
- Frame suggestions as questions, not directives
- Get straight to the point—no formal intros
- Keep comments short and focused on one thing
- Use code blocks to illustrate alternatives

## What to Check

**Security**: Auth/authz, injection risks, exposed secrets, state machine integrity

**Performance**: N+1 queries, missing indexes, caching opportunities, O(n²) on unbounded data

**Quality**:
- Test coverage for changed/deleted code
- Dead code, debug logging, redundant calls
- Silent error handling (should fail loudly)
- Premature DB writes (defer until user confirms)
- Defensive checks that can never fail
- Imprecise naming
- Excessive nesting that could be flattened

## Before You Flag Something

**Be certain.** If you're going to call something a bug, you need to be confident it actually is one.

- Only review the changes - do not review pre-existing code that wasn't modified
- Don't flag something as a bug if you're unsure - investigate first
- Don't invent hypothetical problems - if an edge case matters, explain the realistic scenario where it breaks
- If you need more context to be sure, read more files or use the explore agent

**Don't be a zealot about style.** Some "violations" are acceptable when they're the simplest option.

## Specialist Checklists

Apply based on files changed:

### Security (auth/*, api/*, *auth*, *token*, *.env*)
- [ ] No secrets in code
- [ ] Input validation present
- [ ] Auth checks on protected routes
- [ ] Injection risks addressed (SQL, NoSQL, command)

### Accessibility (*.tsx, *.jsx, *.vue, *.html)
- [ ] Interactive elements keyboard accessible
- [ ] Images have alt text
- [ ] Form inputs have labels
- [ ] Color not sole indicator of state

### Performance (queries/*, *repository*, api/*)
- [ ] N+1 query risk assessed
- [ ] Pagination for unbounded lists
- [ ] Indexes considered for new queries
- [ ] Caching opportunities evaluated

## Output

Keep it short, thoughtful, and helpful. No flattery.
