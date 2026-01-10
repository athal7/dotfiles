---
description: Review changes [commit|branch|pr], defaults to uncommitted
---

Input: $ARGUMENTS

## Workspace Detection

Before reviewing, ensure you're in the correct git repository:

1. **Get git root and branch** - Run:
   ```bash
   git rev-parse --show-toplevel
   git branch --show-current
   ```

2. **Verify context makes sense**:
   - If on `main`/`master` with no uncommitted changes, you're likely in the wrong directory
   - Search for worktrees: `git worktree list`
   - If worktrees exist, identify the one matching the expected feature branch and `cd` to it
   - If no worktrees match, check for devcontainer context using the `devcontainer` tool

3. **Use the correct workspace** for all operations:
   - `cd` to the detected workspace before running git commands
   - Read files (AGENTS.md, source files) from that workspace path

**Do not ask the user which directory to use** - find the right one automatically based on branch names and worktree list.

## Determining What to Review

Based on the input provided, determine which type of review to perform:

1. **No arguments (default)**: Review changes on current branch
   - First check for uncommitted changes: `git diff` and `git diff --cached`
   - If no uncommitted changes, review commits on current branch vs origin default:
     - Detect default branch: `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'`
     - Run: `git diff origin/<default>...HEAD`
   - If both are empty, report "No changes to review"

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

**Quality** (applying Uncle Bob's Clean Code, Fowler's refactoring lens, Beck's test principles):
- Test coverage for changed/deleted code
- Dead code, debug logging, redundant calls
- Silent error handling (should fail loudly)
- Premature DB writes (defer until user confirms)
- Defensive checks that can never fail
- Imprecise naming
- Excessive nesting that could be flattened
- **Functions**: Too long? Doing more than one thing? (Uncle Bob: functions should do one thing)
- **Code smells**: Long Method, Feature Envy (method uses another class's data more than its own), Data Clumps (same group of params passed everywhere), Primitive Obsession (using primitives instead of small objects)
- **Test quality**: Arrange-Act-Assert structure? Testing behavior not implementation? One assertion per test concept?

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
