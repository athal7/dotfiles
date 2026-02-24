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

**After getting the diff:** read entire modified file(s) for full context.

**Read project rules:** Check for and read `AGENTS.md`, `.opencode/AGENTS.md`, `CONVENTIONS.md`, `.github/copilot-instructions.md` in the repo root. These contain project-specific coding standards, architectural decisions, and review expectations. Include relevant rules in the payload to **all** sub-agents (not just maintainability) — security rules go to security, testing expectations go to correctness, etc.

## Static Analysis Pass

**Before any LLM analysis**, run available project linters/checkers on modified files. Detect which tools are available and run them:

1. Check project root for config files to detect tooling:
   - `Gemfile` / `.rubocop.yml` → `bundle exec rubocop --format json <files>`
   - `package.json` → check for eslint/biome scripts → `npx eslint --format json <files>` or `npx biome check <files>`
   - `tsconfig.json` → `npx tsc --noEmit --pretty 2>&1` (type errors only)
   - `Brakeman` (Rails) → `bundle exec brakeman --only-files <files> --format json -q`
   - `pyproject.toml` / `setup.cfg` → `ruff check <files> --output-format json` or `mypy <files>`
   - `.golangci.yml` → `golangci-lint run <files>`

2. Only run tools that are **already configured in the project** — never install new tools.
3. Collect output. Include the raw linter findings in the payload to sub-agents under a `## Static Analysis Findings` section.
4. If no linters are configured or all pass clean, note "No static analysis findings" and move on.

The LLM's job is to find **semantic issues that tools can't catch** — logic errors, missing edge cases, architectural problems. Let tools handle syntax, style, and known vulnerability patterns.

## Dispatch Strategy

Count the diff size (lines changed). Then choose a path:

### Small diff (<150 lines changed): Single-pass

Run the checklist below yourself. Do NOT spawn subagents — the overhead isn't worth it.

**Checklist (scan all):**
- **Security** — secrets, input validation, auth, injection, XSS, CSRF, data exposure
- **Correctness** — edge cases, error handling, async issues, state mutations, inverse symmetry, behavior changes, API contracts
- **Performance** — N+1 queries, over-fetching, missing indexes, O(n^2), pagination
- **Maintainability** — single responsibility, naming, dead code, DRY, test coverage, minimize diff, unused code detection

**Agentic exploration (even for small diffs):** Before flagging any issue, use `grep` and `read` to follow references. If the diff calls a function, read that function. If it changes a type, find all callers. Do not flag "unused code" or "missing error handling" without verifying against the actual codebase.

### Large diff (>=150 lines changed): Parallel specialists

Prepare a **base payload** containing:
1. The full diff
2. Full contents of every modified file
3. Static analysis findings (from the pass above)

Prepare **extended context**:
- **Project rules** (AGENTS.md, CONVENTIONS.md content) — for **all** agents
- **Issue context** (requirements, acceptance criteria) — for correctness and maintainability agents

Then spawn **four Task calls in parallel** (all in a single message), each with `subagent_type` set to the specialist agent name. **Critical: instruct each agent to actively explore the codebase** — they have full tool access (grep, glob, read). Tailor each prompt:

```
Task(subagent_type="review-security", prompt="<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Static Analysis Findings\n<linter output>\n\nReview for security issues. You have full tool access — use grep/read to trace data flows through the codebase. Follow user input from entry point to database/output. Check auth boundaries by reading middleware and controller filters. Also read AGENTS.md and CONVENTIONS.md yourself for any security-specific rules. For each finding, include a concrete suggested fix as a code block.\n\nReturn a JSON array: [{\"file\": \"path\", \"line\": N, \"severity\": \"blocker|suggestion|nit\", \"issue\": \"short title\", \"detail\": \"1 sentence\", \"suggested_fix\": \"code snippet or null\"}]")

Task(subagent_type="review-correctness", prompt="<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Issue Context\n<issue details, requirements, acceptance criteria>\n\n## Static Analysis Findings\n<linter output>\n\nReview for correctness and logic issues. You have full tool access — use grep/read to verify assumptions. Read test files to check coverage. Trace function calls to verify contracts. Check inverse operations (create/delete, serialize/deserialize). Also read AGENTS.md yourself for testing and correctness expectations. For each finding, include a concrete suggested fix as a code block.\n\nReturn a JSON array: [{\"file\": \"path\", \"line\": N, \"severity\": \"blocker|suggestion|nit\", \"issue\": \"short title\", \"detail\": \"1 sentence\", \"suggested_fix\": \"code snippet or null\"}]")

Task(subagent_type="review-performance", prompt="<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Static Analysis Findings\n<linter output>\n\nReview for performance issues. You have full tool access — use grep/read to check query patterns, index definitions, and data volumes. Look at database migrations/schema for missing indexes. Check for N+1 by reading association definitions. Also read AGENTS.md yourself for performance-related conventions. For each finding, include a concrete suggested fix as a code block.\n\nReturn a JSON array: [{\"file\": \"path\", \"line\": N, \"severity\": \"blocker|suggestion|nit\", \"issue\": \"short title\", \"detail\": \"1 sentence\", \"suggested_fix\": \"code snippet or null\"}]")

Task(subagent_type="review-maintainability", prompt="<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Issue Context\n<issue details>\n\n## Static Analysis Findings\n<linter output>\n\nReview for maintainability issues. You have full tool access — use grep/read to check naming conventions across the codebase, verify DRY violations by finding similar patterns, and confirm dead code by searching for call sites. Read AGENTS.md and CONVENTIONS.md thoroughly — maintainability findings must align with established project conventions. For each finding, include a concrete suggested fix as a code block.\n\nReturn a JSON array: [{\"file\": \"path\", \"line\": N, \"severity\": \"blocker|suggestion|nit\", \"issue\": \"short title\", \"detail\": \"1 sentence\", \"suggested_fix\": \"code snippet or null\"}]")
```

Each specialist returns a JSON array of findings.

### Merge and Verify Results

After all specialists return:
1. Parse each JSON array
2. Deduplicate — if two specialists flag the same line, keep the higher-severity one and note both concerns
3. **Verification pass** — for each finding, spot-check it against the codebase:
   - "Unused variable/function" → grep for usages; discard if found
   - "Missing null check" → read the caller to see if it's already guarded upstream
   - "N+1 query" → check if eager loading is configured elsewhere (e.g., default_scope, includes)
   - "Security: user input unsanitized" → trace the input to see if a framework-level sanitizer handles it
   - Discard any finding you cannot verify. Prefer fewer, higher-confidence comments over volume.
4. Classify remaining findings into: Blockers, Suggestions, Nits
5. Determine verdict based on blockers

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
  ```suggestion
  # concrete replacement code
  ```

## Suggestions (non-blocking)

- **file.rb:25** - [2-5 word suggestion]
  ```suggestion
  # concrete replacement code
  ```

## Nits

- **file.rb:30** - [tiny thing]
```

**Rules:**
- Skip sections with no items (don't say "None")
- Max 1-2 sentences per item. No filler.
- **Always include a `suggestion` code block** with the concrete fix, unless the fix requires architectural changes that can't be expressed as a snippet
- Use "I" statements, frame as questions not directives

**For PRs:** add TL;DR at top. If issue context found, add Requirements Check after verdict.
