---
name: review-checklist
description: Code review checklist - coordinates specialist reviewers for thorough analysis
---

## PR Review Rules

**"Review this PR" means:** analyze and draft a written review — do NOT submit to GitHub or implement fixes unless explicitly asked.

**Conflict resolution on reviewed PRs:** When a PR has reviews and conflicts with the base branch, use `git merge` (not `git rebase`) to resolve them. Rebasing rewrites history and invalidates existing review comments.

**Submitting reviews:** Show the full proposed review content and ask "Do you approve?" before submitting to GitHub — then STOP and wait for explicit approval. Load the `gh-pr-inline` skill when posting inline comments or responding to review feedback.

---

## PR Checkout

**If reviewing a PR** (URL or number provided): check out the PR branch locally before doing anything else.

```bash
gh pr checkout <PR_NUMBER>
```

This ensures local files reflect the PR's code, enabling accurate diff panel display and local file reads. Save the original branch first so you can restore it if needed:

```bash
ORIGINAL_BRANCH=$(git branch --show-current)
gh pr checkout <PR_NUMBER>
# ... review ...
git checkout $ORIGINAL_BRANCH  # restore when done
```

If `gh pr checkout` fails (e.g., the repo isn't local), fall back to `gh pr diff` for the diff and `gh pr view` for metadata.

---

## Context Gathering

**Read `.opencode/context-log.md`** first for issue context and build history.

**Extract issue IDs** from branch name or PR, then fetch details:
1. `git branch --show-current` — parse for `ENG-123`, `PROJ-456`, `#123`, `gh-123`
2. For PRs: check PR body and linked issues via `gh pr view --json body,title`
3. Fetch: Linear → `team-context_get_issue`, GitHub → `gh issue view`
4. **Fetch project context** — if the Linear issue belongs to a project, also fetch:
   - `team-context_get_project` — project metadata, goals, status
   - `team-context_get_project_body` — full project description with scope, non-goals, and design decisions
   - `team-context_get_milestone` — current milestone with target date and deliverables (if applicable)

   Project context reveals the *why* behind the issue — business goals, related features, constraints, and existing decisions that the diff should align with. Include it in the payload to correctness and maintainability agents.

**Use context to verify:** requirements alignment, acceptance criteria, scope creep, project goals, and consistency with related issues in the same project.

**After getting the diff:** read entire modified file(s) for full context.

**For PR reviews, fetch prior review history:**
1. `gh pr reviews <PR> --json author,state,submittedAt,body` — all submitted reviews with their verdict and top-level body
2. `gh api repos/{owner}/{repo}/pulls/<PR_NUMBER>/comments` — all inline review comments; note `path`, `line`, `body`, `in_reply_to_id` (a non-null `in_reply_to_id` means it's a reply in a thread)
3. Build a **prior review summary**: group inline comments by thread (using `in_reply_to_id`), identify the last message per thread, and mark threads as:
   - **Resolved** — author replied acknowledging the fix, or the thread was explicitly resolved
   - **Unresolved** — no author reply, or last reply disagrees/defers
4. Attach the full prior review summary to the payload for all sub-agents.

**Read project rules:** Check for and read `AGENTS.md`, `.opencode/AGENTS.md`, `CONVENTIONS.md`, `.github/copilot-instructions.md`, `REVIEW.md`, and `CONTRIBUTING.md` in the repo root. Also check `docs/` for development guides (e.g., `docs/development.md`, `docs/writing-probes.md`) that may contain framework-specific conventions (minimum test counts, data file conventions, naming patterns) that generic review cannot infer. `REVIEW.md` contains review-specific guidance (paths to skip, things to always flag, team conventions) — treat it as the highest-priority override. Include relevant rules in the payload to **all** sub-agents (not just maintainability) — security rules go to security, testing expectations go to correctness, etc.

## Static Analysis Pass

**Before any LLM analysis**, run available project linters/checkers on modified files. Detect which tools are available and run them. Run all applicable tools in parallel.

1. Check project root for config files to detect tooling:

   **Style & quality:**
   - `Gemfile` / `.rubocop.yml` → `bundle exec rubocop --format json <files>`
   - `package.json` → check for eslint/biome scripts → `npx eslint --format json <files>` or `npx biome check <files>`
   - `pyproject.toml` / `setup.cfg` → `ruff check <files> --output-format json`
   - `.golangci.yml` → `golangci-lint run <files>`

   **Type checking:**
   - `tsconfig.json` → `npx tsc --noEmit --pretty 2>&1` (type errors only)
   - `pyproject.toml` with mypy config → `mypy <files>`
   - `sorbet/` or `Gemfile` with sorbet → `bundle exec srb tc <files>`

   **Security:**
   - `Gemfile` with brakeman → `bundle exec brakeman --only-files <files> --format json -q`
   - `Gemfile` with bundler-audit → `bundle exec bundler-audit check --update`
   - `package.json` → `npm audit --json` or `yarn audit --json`
   - `Gemfile` / `package.json` → check for `importmap` or `yarn.lock` changes and flag new dependencies for review

2. Only run tools that are **already configured in the project** — never install new tools.
3. Collect output. Include the raw linter findings in the payload to sub-agents under a `## Static Analysis Findings` section. Tag each finding with its source tool so specialists know what's already been caught mechanically.
4. If no linters are configured or all pass clean, note "No static analysis findings" and move on.

The LLM's job is to find **semantic issues that tools can't catch** — logic errors, missing edge cases, architectural problems. Let tools handle syntax, style, and known vulnerability patterns. If a static analysis tool already flagged an issue, specialists should NOT re-report it (it's already in the output) — they should only add findings the tools missed.

## Dispatch Strategy

**Do not review the diff yourself** — your job is coordination: gather context, build the payload, dispatch, handle escalations, merge, verify, and format output.

### Classify the diff

Before dispatching, scan the diff to determine which specialists are relevant:

| Signal | Triggers |
|---|---|
| **Models, services, controllers, jobs, lib** | correctness, completeness, maintainability |
| **Removes/renames columns, enums, scopes, methods** | completeness (propagation) |
| **ORM calls: `update_column`, `delete`, caching, type patterns** | conventions |
| **DB queries, loops over collections, views rendering lists** | performance |
| **Auth, params, cookies, sessions, CORS, encryption** | security |
| **Migrations, schema changes** | performance + completeness |
| **Views, templates, JS, CSS, frontend components** | maintainability (UX) + performance (UI scalability) |
| **Config files, routes, environment settings** | security |
| **Test files** | maintainability (test validity) |

### Dispatch rules

**Always dispatch:** correctness, completeness, maintainability — these three cover the highest-value issues on every diff.

**Conditional:**
- **Conventions**: dispatch if the diff uses ORM persistence methods, caching, or introduces new data models/columns. Skip for pure view or config changes.
- **Security**: dispatch if the diff touches auth, params, cookies/sessions, encryption, CORS, environment config, or dependencies. Skip for purely internal logic or views.
- **Performance**: dispatch if the diff touches DB queries, associations, loops, jobs processing batches, views rendering collections, or migrations. Skip for config or documentation.

When in doubt, **dispatch** — false negatives are worse than wasted tokens.

### Build payloads

Prepare a **base payload** containing:
1. The full diff
2. Full contents of every modified file
3. Static analysis findings (from the pass above)
4. Prior review summary (for PRs — threads with resolved/unresolved status; omit section if not a PR review)

Prepare **extended context**:
- **Project rules** (AGENTS.md, CONVENTIONS.md content) — for **all** agents
- **Issue context** (requirements, acceptance criteria, project goals) — for correctness and maintainability agents
  - Use the **actual fetched text** from `team-context_get_issue` / `gh issue view` — not the placeholder.
  - If the issue belongs to a Linear project, include the project body (`team-context_get_project_body`) and milestone context. This gives reviewers the broader product vision — business goals, related features, existing decisions, and constraints that should inform the review.
  - If no issue was found, write "No issue context available."
- **Prior reviews** (PR only) — for **all** agents; include the full prior review summary

### Spawn specialists

Spawn all applicable specialists **in parallel** (all in a single message), all with `subagent_type="expert"`. Each prompt tells the expert to load a specific review skill.

**Always dispatch (every review):**
```
Task("review-correctness", payload + Issue Context + Project Rules + Static Analysis + Prior Reviews)
Task("review-completeness", payload + Issue Context + Project Rules + Static Analysis + Prior Reviews)
Task("review-maintainability", payload + Issue Context + Project Rules + Static Analysis + Prior Reviews)
```

**Conditional (only when relevant signals detected):**
```
Task("review-conventions", payload + Project Rules + Static Analysis + Prior Reviews)
Task("review-security", payload + Project Rules + Static Analysis + Prior Reviews)
Task("review-performance", payload + Project Rules + Static Analysis + Prior Reviews)
```

Each Task prompt follows this template:
```
Load the `review-<skill>` skill and follow its instructions.

<base payload>

## Project Rules
<AGENTS.md / CONVENTIONS.md content>

## Issue Context          ← only for correctness, completeness, maintainability
<issue details, acceptance criteria, project body>

## Static Analysis Findings
<linter output>

## Prior Reviews
<prior review summary or 'N/A — not a PR review'>
```

Each specialist returns `{"findings": [...], "escalations": [...]}`.

**Escalation routing:** If a specialist was skipped but another specialist escalates to it, the escalation handler dispatches it as a follow-up.

### Handle Escalations

After all specialists return, collect all `escalations` from each specialist's output. For each escalation:

1. Group escalations by `for_reviewer` (correctness / completeness / conventions / maintainability / security / performance)
2. If any group is non-empty, spawn **targeted follow-up Task calls** — one per group — with `subagent_type="expert"`.

Follow-up template:
```
Load the `review-<domain>` skill. The following areas were flagged by other reviewers:

<list of escalations with file:line and note>

Full diff: <diff>
Full file contents: <files>
## Project Rules: <content>
## Issue Context: <if applicable>
## Static Analysis: <output>

This is a follow-up pass. Put all issues in `findings`. Escalations will be discarded.
```

Include `## Issue Context` for correctness, completeness, and maintainability follow-ups. Omit for security, performance, and conventions.

Follow-up agents return additional `findings`. The coordinator discards all `escalations` from follow-ups to prevent infinite loops.

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

The correctness specialist traces side effect chains in Phase 1. When building the payload, explicitly flag any callbacks, jobs, events, or webhooks visible in the diff so it traces them.

## Coordinator-Level Checks

After merging specialist findings, the coordinator adds these checks directly (not delegated to specialists):

1. **Missing acceptance criteria** — if no linked issue with acceptance criteria was found, add a suggestion: "No linked issue with acceptance criteria found — cannot fully verify feature completeness. Consider linking an issue with specific acceptance criteria."

2. **Runtime verification required** — if the diff modifies views, templates, controllers, frontend code, or UI interactions, **run QA automatically** after all findings are merged:

   1. **Record the current branch** (save as `$ORIGINAL_BRANCH`) — already done if reviewing a PR (see PR Checkout section above)
   2. **Check out the code under review** (if not already done):
      - PR: already checked out via the PR Checkout step
      - Branch: `git checkout $BRANCH_NAME`
      - Commit/staged/uncommitted: already checked out — skip
   3. **Run `/qa`** — pass relevant context about which flows were changed (e.g., "login form was modified")
   4. **Restore the original branch:** `git checkout $ORIGINAL_BRANCH`
   5. **Include QA results** in the review output under a `## QA Results` section after Pre-existing Issues.

   Do not add a note suggesting QA — execute it and report the results.

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
