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

**Always dispatch to specialists.** Do not review the diff yourself — your job is coordination: gather context, build the payload, dispatch, handle escalations, merge, verify, and format output.

### Parallel specialists

Prepare a **base payload** containing:
1. The full diff
2. Full contents of every modified file
3. Static analysis findings (from the pass above)

Prepare **extended context**:
- **Project rules** (AGENTS.md, CONVENTIONS.md content) — for **all** agents
- **Issue context** (requirements, acceptance criteria) — for correctness and maintainability agents
  - Use the **actual fetched text** from `team-context_get_issue` / `gh issue view` — not the placeholder.
  - If no issue was found, write "No issue context available."

Then spawn **four Task calls in parallel** (all in a single message), all with `subagent_type="expert"`. Each prompt instructs the expert to load a specific review skill. Tailor each prompt:

```
Task(subagent_type="expert", prompt="Load the `review-security` skill and follow its instructions.\n\n<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Static Analysis Findings\n<linter output>")

Task(subagent_type="expert", prompt="Load the `review-correctness` skill and follow its instructions.\n\n<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Issue Context\n<issue details, requirements, acceptance criteria>\n\n## Static Analysis Findings\n<linter output>")

Task(subagent_type="expert", prompt="Load the `review-performance` skill and follow its instructions.\n\n<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Static Analysis Findings\n<linter output>")

Task(subagent_type="expert", prompt="Load the `review-maintainability` skill and follow its instructions.\n\n<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Issue Context\n<issue details, requirements, acceptance criteria>\n\n## Static Analysis Findings\n<linter output>")
```

Each specialist returns a JSON object containing a `findings` array and an `escalations` array.

### Handle Escalations

After all specialists return, collect all `escalations` from each specialist's output. For each escalation:

1. Group escalations by `for_reviewer` (security / correctness / performance / maintainability)
2. If any group is non-empty, spawn **targeted follow-up Task calls** — one per group — with `subagent_type="expert"`.

For **correctness or maintainability** follow-ups (include `## Issue Context`):
```
Task(subagent_type="expert", prompt="Load the `review-<domain>` skill. The following specific areas were flagged by other reviewers as needing your attention:\n\n<list of escalations with file:line and note>\n\nFull diff:\n<diff>\n\nFull file contents:\n<files>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Issue Context\n<issue details, requirements, acceptance criteria>\n\n## Static Analysis Findings\n<linter output>\n\nNote: This is a follow-up review pass. Put all issues you find in `findings`. Any `escalations` you output will be discarded by the coordinator — focus only on findings.")
```

For **security or performance** follow-ups (no `## Issue Context`):
```
Task(subagent_type="expert", prompt="Load the `review-<domain>` skill. The following specific areas were flagged by other reviewers as needing your attention:\n\n<list of escalations with file:line and note>\n\nFull diff:\n<diff>\n\nFull file contents:\n<files>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Static Analysis Findings\n<linter output>\n\nNote: This is a follow-up review pass. Put all issues you find in `findings`. Any `escalations` you output will be discarded by the coordinator — focus only on findings.")
```

These follow-up agents return additional `findings`. The coordinator discards all `escalations` from follow-up agents to prevent infinite loops.

### Merge and Verify Results

After all specialists and follow-up agents return:

1. Collect all `findings` from all agents (initial + follow-up)
2. Deduplicate — if two specialists flag the same line, keep the higher-severity one and note both concerns
3. **Additive verification pass** — for each finding, verify it against the codebase:
   - "Unused variable/function" → grep for usages; discard if found
   - "Missing null check" → read the caller to see if it's already guarded upstream
   - "N+1 query" → check if eager loading is configured elsewhere (e.g., default_scope, includes)
   - "Security: user input unsanitized" → trace the input to see if a framework-level sanitizer handles it
   - Discard any finding you cannot verify
   - **While verifying, read the surrounding code actively** — if you spot a new issue the specialists missed, add it to the list. Specifically look for cross-cutting concerns: security implications of correctness issues, correctness implications of performance changes. You are not only pruning — you are also a final reviewer.
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

**For PRs:** extend the output as follows:

```markdown
[PR URL as clickable link]

## TL;DR

[One sentence summary of what this PR does]

## Verdict: [APPROVE | CHANGES REQUESTED | COMMENT]

[One sentence why, if not obvious]

## Requirements Check

> Only include this section if issue context was found.

- [Acceptance criterion 1]: [met / not met — one sentence]
- [Acceptance criterion 2]: [met / not met — one sentence]

## Blockers
...
```
