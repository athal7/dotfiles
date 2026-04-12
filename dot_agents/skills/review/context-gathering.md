
## Context Gathering

**Read `.opencode/context-log.md`** first for issue context and build history.

**Extract issue IDs** from branch name or PR, then fetch details:
1. `git branch --show-current` — parse for `ENG-123`, `PROJ-456`, `#123`, `gh-123`
2. For PRs: check PR body and linked issues via `gh pr view --json body,title`
3. Fetch: Linear → use your `search-issues` capability to query via `gq`, GitHub → `gh issue view`
4. **Fetch project context** — if the Linear issue belongs to a project, also fetch via your `search-issues` capability:
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
