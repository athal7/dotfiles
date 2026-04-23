
## Context Gathering

**Read `.opencode/context-log.md`** first for issue context and build history.

**For merge requests — fetch prior review history** using your `source-control` capability before doing anything else:

1. All submitted reviews with their verdict and top-level body
2. All inline review comments, including `path`, `line`, `body`, and reply thread relationships
3. Build a **prior review summary**: group inline comments by thread, identify the last message per thread, and mark each thread as:
   - **Resolved** — author replied acknowledging the fix, or the thread was explicitly resolved
   - **Awaiting reviewer** — author has replied (most recent message is from the merge request author) but no reviewer response yet
   - **Unresolved** — no author reply, or last reply disagrees/defers
4. Attach the full prior review summary to the payload for all sub-agents.

**Prior review output rules:**
- Do NOT re-raise issues already raised and addressed (author replied with a fix, or code changed to resolve it).
- DO surface unresolved threads in "Unresolved Prior Feedback" — higher priority than new findings.
- DO surface awaiting-reviewer threads in "Awaiting Your Response" — the author is blocked waiting on the reviewer.
- Unresolved prior feedback counts toward the verdict the same as blockers if originally `CHANGES REQUESTED`.
- If a new finding duplicates an unresolved prior comment, merge them: cite the prior comment and note it remains unresolved.

---

**Extract issue IDs** from branch name or merge request, then fetch details:
1. Parse the current branch name for issue IDs (e.g. `ENG-123`, `PROJ-456`, `#123`)
2. For merge requests: fetch body and linked issues via your `source-control` capability
3. Fetch issue details via your `issues` capability
4. **Fetch project context** — if the issue belongs to a project, also fetch via your `issues` capability:
   - project metadata, goals, status
   - full project description with scope, non-goals, and design decisions
   - current milestone with target date and deliverables (if applicable)

   Project context reveals the *why* behind the issue — business goals, related features, constraints, and existing decisions that the diff should align with. Include it in the payload to correctness and maintainability agents.

**Use context to verify:** requirements alignment, acceptance criteria, scope creep, project goals, and consistency with related issues in the same project.

**After getting the diff:** read modified files for full context. Prioritize files with substantive logic changes; skip generated files, lock files, and vendored code.

**Read project rules:** Check for and read `AGENTS.md`, `.opencode/AGENTS.md`, `CONVENTIONS.md`, `.github/copilot-instructions.md`, `REVIEW.md`, and `CONTRIBUTING.md` in the repo root. Also check `docs/` for development guides (e.g., `docs/development.md`, `docs/writing-probes.md`) that may contain framework-specific conventions (minimum test counts, data file conventions, naming patterns) that generic review cannot infer. `REVIEW.md` contains review-specific guidance (paths to skip, things to always flag, team conventions) — treat it as the highest-priority override. Include the full project rules text in every specialist payload — let each specialist extract what's relevant to their domain.

---

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
3. Collect output. Include the raw linter findings in the payload to sub-agents under a `## Static Analysis Findings` section. Tag each finding with its source tool.
4. If no linters are configured or all pass clean, note "No static analysis findings" and move on.

The LLM's job is to find **semantic issues that tools can't catch** — logic errors, missing edge cases, architectural problems. If a static analysis tool already flagged an issue, specialists should NOT re-report it — they should only add findings the tools missed.
