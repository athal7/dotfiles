---
name: review-checklist
description: Code review checklist - coordinates specialist reviewers for thorough analysis
---

## Context Gathering

**Read `.opencode/context-log.md`** first for issue context and build history.

**Extract issue IDs** from branch name or PR, then fetch details:
1. `git branch --show-current` — parse for `ENG-123`, `PROJ-456`, `#123`, `gh-123`
2. For PRs: check PR body and linked issues via `gh pr view --json body,title`
3. Fetch: Linear → `team-context_get_issue`, GitHub → `gh issue view`

**Use context to verify:** requirements alignment, acceptance criteria, scope creep, project goals.

**After getting the diff:** read entire modified file(s) for full context. Check for CONVENTIONS.md, AGENTS.md.

## Dispatch Strategy

Count the diff size (lines changed). Then choose a path:

### Small diff (<150 lines changed): Single-pass

Run the checklist below yourself. Do NOT spawn subagents — the overhead isn't worth it.

**Checklist (scan all):**
- **Security** — secrets, input validation, auth, injection, XSS, CSRF, data exposure
- **Correctness** — edge cases, error handling, async issues, state mutations, inverse symmetry, behavior changes, API contracts
- **Performance** — N+1 queries, over-fetching, missing indexes, O(n^2), pagination
- **Maintainability** — single responsibility, naming, dead code, DRY, test coverage, minimize diff, unused code detection

Before flagging unused code, **read call sites** to verify. Before flagging style, verify it actually violates project conventions.

### Large diff (>=150 lines changed): Parallel specialists

Prepare a **base payload** containing:
1. The full diff
2. Full contents of every modified file

Prepare **extended context** (only for agents that need it):
- **Issue context** (requirements, acceptance criteria) — for correctness and maintainability agents
- **Project conventions** (CONVENTIONS.md, AGENTS.md) — for maintainability agent

Then spawn **four Task calls in parallel** (all in a single message), each with `subagent_type` set to the specialist agent name. Tailor each prompt:

```
Task(subagent_type="review-security",        prompt="<base payload>\n\nReview for security issues only.")
Task(subagent_type="review-correctness",     prompt="<base payload>\n\n## Issue Context\n<issue details, requirements, acceptance criteria>\n\nReview for correctness and logic issues only.")
Task(subagent_type="review-performance",     prompt="<base payload>\n\nReview for performance issues only.")
Task(subagent_type="review-maintainability", prompt="<base payload>\n\n## Issue Context\n<issue details>\n\n## Project Conventions\n<conventions>\n\nReview for maintainability issues only.")
```

Each specialist returns a JSON array of findings.

### Merge Results

After all specialists return:
1. Parse each JSON array
2. Deduplicate — if two specialists flag the same line, keep the higher-severity one and note both concerns
3. Classify into: Blockers, Suggestions, Nits
4. Determine verdict based on blockers

## Side Effects Check

Regardless of path, always trace the callback/job chain:
- Does this trigger emails, notifications, webhooks?
- Side effects should fire after the operation succeeds, not before
- Guard clauses and early returns belong at the top

## Output Format

**Be terse.** Developers can read code — don't explain what the diff does.

```markdown
## Verdict: [APPROVE | CHANGES REQUESTED | COMMENT]

[One sentence why, if not obvious]

## Blockers

- **file.rb:10** - [2-5 word issue]. [1 sentence context if needed]

## Suggestions (non-blocking)

- **file.rb:25** - [2-5 word suggestion]

## Nits

- **file.rb:30** - [tiny thing]
```

**Rules:**
- Skip sections with no items (don't say "None")
- Max 1-2 sentences per item. No filler.
- Use code snippets only if fix is non-obvious
- Use "I" statements, frame as questions not directives

**For PRs:** add TL;DR at top. If issue context found, add Requirements Check after verdict.
