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

**For PR reviews, fetch prior review history:**
1. `gh pr reviews <PR> --json author,state,submittedAt,body` — all submitted reviews with their verdict and top-level body
2. `gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments` — all inline review comments; note `path`, `line`, `body`, `in_reply_to_id` (a non-null `in_reply_to_id` means it's a reply in a thread)
3. Build a **prior review summary**: group inline comments by thread (using `in_reply_to_id`), identify the last message per thread, and mark threads as:
   - **Resolved** — author replied acknowledging the fix, or the thread was explicitly resolved
   - **Unresolved** — no author reply, or last reply disagrees/defers
4. Attach the full prior review summary to the payload for all sub-agents.

**Read project rules:** Check for and read `AGENTS.md`, `.opencode/AGENTS.md`, `CONVENTIONS.md`, `.github/copilot-instructions.md`, and `REVIEW.md` in the repo root. `REVIEW.md` contains review-specific guidance (paths to skip, things to always flag, team conventions) — treat it as the highest-priority override. Include relevant rules in the payload to **all** sub-agents (not just maintainability) — security rules go to security, testing expectations go to correctness, etc.

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
4. Prior review summary (for PRs — threads with resolved/unresolved status; omit section if not a PR review)

Prepare **extended context**:
- **Project rules** (AGENTS.md, CONVENTIONS.md content) — for **all** agents
- **Issue context** (requirements, acceptance criteria) — for correctness and maintainability agents
  - Use the **actual fetched text** from `team-context_get_issue` / `gh issue view` — not the placeholder.
  - If no issue was found, write "No issue context available."
- **Prior reviews** (PR only) — for **all** agents; include the full prior review summary

Then spawn **four Task calls in parallel** (all in a single message), all with `subagent_type="expert"`. Each prompt instructs the expert to load a specific review skill. Tailor each prompt:

```
Task(subagent_type="expert", prompt="Load the `review-security` skill and follow its instructions.\n\n<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Static Analysis Findings\n<linter output>\n\n## Prior Reviews\n<prior review summary or 'N/A — not a PR review'>")

Task(subagent_type="expert", prompt="Load the `review-correctness` skill and follow its instructions.\n\n<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Issue Context\n<issue details, requirements, acceptance criteria>\n\n## Static Analysis Findings\n<linter output>\n\n## Prior Reviews\n<prior review summary or 'N/A — not a PR review'>")

Task(subagent_type="expert", prompt="Load the `review-performance` skill and follow its instructions.\n\n<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Static Analysis Findings\n<linter output>\n\n## Prior Reviews\n<prior review summary or 'N/A — not a PR review'>")

Task(subagent_type="expert", prompt="Load the `review-maintainability` skill and follow its instructions.\n\n<base payload>\n\n## Project Rules\n<AGENTS.md / CONVENTIONS.md content>\n\n## Issue Context\n<issue details, requirements, acceptance criteria>\n\n## Static Analysis Findings\n<linter output>\n\n## Prior Reviews\n<prior review summary or 'N/A — not a PR review'>")
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
3. **Verification pass** — for each finding, attempt to disprove it using the method appropriate to the claim:

   | Claim type | How to disprove |
   |---|---|
   | "Unused variable/function" | `rg` for all usages including dynamic calls, string interpolation, metaprogramming; discard only if zero real usages found |
   | "Missing null check" | Read the full call chain upstream — is there a guard, `presence` validation, or DB constraint that guarantees non-null? Discard only if protection is confirmed |
   | "N+1 query" | Check `default_scope`, `after_find`, controller `includes`, and any concern that wraps the association; discard only if eager loading is confirmed for this access path |
   | "Unsanitized input" | Trace the full input path — does a framework layer (Rack, Rails strong params, ORM) sanitize it before use? Discard only if sanitization is confirmed end-to-end |
   | "Race condition" | Read the surrounding transaction, lock, or mutex scope; discard only if the critical section is provably atomic |
   | "Side effect fires on failure" | Read the callback/hook definition and check whether it is wrapped in `after_commit`, `after_save` with a condition, or guarded by the success of the preceding operation |
   | "Pre-existing" tag | Confirm with `git blame` — if the line was touched by this diff, reclassify to appropriate severity |

   **Default: keep, don't discard.** Discard a finding only if you can positively disprove the claim above. A finding that is hard to verify is not the same as a false positive. When in doubt, keep it as a `suggestion` with a note that further investigation is needed.

   **While verifying, read the surrounding code actively** — if you spot a new issue the specialists missed, add it to the list. Specifically look for cross-cutting concerns: security implications of correctness issues, correctness implications of performance changes. You are not only pruning — you are also a final reviewer.

4. Classify remaining findings:
   - `blocker` → **Blockers** section
   - `suggestion` → **Suggestions** section
   - `nit` → **Nits** section
   - `pre-existing` → **Pre-existing Issues** section (separate, never affects verdict)
5. Determine verdict based on blockers only (pre-existing findings never trigger CHANGES REQUESTED)

## Side Effects Check

The correctness specialist handles side effect tracing as part of Phase 1. When building the payload for the correctness agent, explicitly flag any callbacks, jobs, events, or webhooks visible in the diff so the specialist traces them. If the diff modifies an `after_*` callback, background job, or event emitter, include the full chain in the base payload.

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

## Pre-existing Issues

> These bugs exist in the codebase but were not introduced by this PR. They do not affect the verdict.

- **file.rb:55** - [issue title]. [1 sentence explanation]
```

**Rules:**
- Skip sections with no items (don't say "None")
- Max 1-2 sentences per item. No filler.
- **Always include a `suggestion` code block** with the concrete fix, unless the fix requires architectural changes that can't be expressed as a snippet
- Use "I" statements, frame as questions not directives
- Pre-existing Issues never influence the verdict — they are informational only

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

## Unresolved Prior Feedback

> Only include this section if prior reviews exist and any threads are still unresolved.

- **file.rb:10** (@reviewer, [date]) - [original comment summary]. [Status: author hasn't responded / author replied but issue remains]

## Blockers
...

## Pre-existing Issues

> These bugs exist in the codebase but were not introduced by this PR. They do not affect the verdict.

- **file.rb:55** - [issue title]. [1 sentence explanation]
```

**Prior review rules:**
- Do NOT re-raise issues that were already raised in a prior review and have been addressed (author replied with a fix, or the code changed to resolve it). Mark them as handled.
- DO surface unresolved threads in the "Unresolved Prior Feedback" section — these are higher priority than new findings since they represent reviewer expectations not yet met.
- Unresolved prior feedback counts toward the verdict the same as blockers if they were originally `CHANGES REQUESTED` items.
- If a new finding duplicates an unresolved prior comment, merge them: cite the prior comment and note it remains unresolved rather than presenting it as a fresh finding.
