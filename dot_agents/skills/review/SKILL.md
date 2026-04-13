---
name: review
description: Review changes [commit|branch|pr|staged], defaults to uncommitted
license: MIT
compatibility: opencode
metadata:
  author: athal7
  version: "1.0"
  requires:
    - source-control
    - qa
---

Fetch the diff based on input, then follow all instructions below.

- **No arguments**: `git diff` + `git diff --cached` + `git status --short`, then `git diff origin/<default>...HEAD`
- **`staged`** (or **`pre-commit`**): `git diff --cached` only
- **Commit hash**: `git show <hash>`
- **Branch name**: `git diff <branch>...HEAD`
- **PR URL/number**: `gh pr view`, `gh pr diff`

**If reviewing a PR:** read `~/.agents/skills/review/pr-workflow.md` now — it covers PR checkout, review rules, submission policy, and prior review history. Follow all instructions there before proceeding.

---

## Phase 1: Context & Static Analysis

Read `~/.agents/skills/review/context-gathering.md` and follow all steps (issue context, project rules, static analysis pass).

---

## Phase 2: Dispatch Specialists

**Do not review the diff yourself** — coordinate: gather context, dispatch, handle escalations, merge, verify, format.

### Classify the diff

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

**Always dispatch:** correctness, completeness, maintainability.

**Conditional:**
- **Conventions**: dispatch if the diff uses ORM persistence methods, caching, or introduces new data models/columns.
- **Security**: dispatch if the diff touches auth, params, cookies/sessions, encryption, CORS, environment config, or dependencies.
- **Performance**: dispatch if the diff touches DB queries, associations, loops, jobs processing batches, views rendering collections, or migrations.

When in doubt, dispatch — false negatives are worse than wasted tokens.

### Build payloads

**Base payload:**
1. The full diff
2. Full contents of modified files (skip generated files, lock files, vendored code)
3. Static analysis findings
4. Prior review summary (PR only; omit if not a PR)

**Extended context (add to each specialist's prompt):**
- **Project rules** — full text of AGENTS.md, CONVENTIONS.md, etc. — for **all** agents
- **Issue context** — requirements, acceptance criteria, project goals — for correctness, completeness, maintainability only; write "No issue context available" if none found
- **Prior reviews** — full prior review summary — for **all** agents (PR only)

### Spawn specialists

Read these files before dispatching:

```
~/.agents/skills/review/specialists/_preamble.md     ← always
~/.agents/skills/review/specialists/correctness.md
~/.agents/skills/review/specialists/completeness.md
~/.agents/skills/review/specialists/maintainability.md
~/.agents/skills/review/specialists/conventions.md   ← if applicable
~/.agents/skills/review/specialists/security.md      ← if applicable
~/.agents/skills/review/specialists/performance.md   ← if applicable
```

Spawn all applicable specialists **in parallel** (single message), all with `subagent_type="expert"`. Inline the specialist instructions directly — do not tell the expert to load a skill.

Each Task prompt:
```
You are a <domain> reviewer. Follow these instructions:

<contents of specialists/<domain>.md>

<contents of specialists/_preamble.md>

<base payload>

## Project Rules
<full project rules text>

## Issue Context          ← only for correctness, completeness, maintainability
<issue details, acceptance criteria, project body>

## Static Analysis Findings
<linter output>

## Prior Reviews
<prior review summary or 'N/A — not a PR review'>
```

Each specialist returns `{"findings": [...], "escalations": [...]}`.

### Handle Escalations

After all specialists return, collect all `escalations`. Group by `for_reviewer`. For each non-empty group, spawn a follow-up Task (one per group):

```
You are a <domain> reviewer. Follow these instructions:

<contents of specialists/<domain>.md>

<contents of specialists/_preamble.md>

The following areas were flagged by other reviewers:
<list of escalations with file:line and note>

Full diff: <diff>
Full file contents: <files>
## Project Rules: <content>
## Issue Context: <if applicable — correctness/completeness/maintainability only>
## Static Analysis: <output>

This is a follow-up pass. Put all issues in `findings`. Escalations will be discarded.
```

Follow-up agents return additional `findings`. Discard all `escalations` from follow-ups to prevent loops.

---

## Phase 3: Merge, Verify & Output

**Side effects note:** when building the payload, explicitly flag any callbacks, jobs, events, or webhooks visible in the diff — the correctness specialist traces these in Phase 1.

Read `~/.agents/skills/review/verify-findings.md` and follow the merge and verification steps.

### Coordinator-Level Checks

After merging specialist findings, add these directly:

1. **Missing acceptance criteria** — if no linked issue with acceptance criteria was found, add a suggestion: "No linked issue with acceptance criteria found — cannot fully verify feature completeness."

2. **Runtime verification** — if the diff modifies views, templates, controllers, frontend code, or UI interactions, run QA automatically:
   1. Ensure the code under review is checked out (PR: already done; branch: `git checkout $BRANCH_NAME`; staged/uncommitted: skip)
    2. Use the `qa` capability — pass context about which flows changed
   3. Restore original branch if needed: `git checkout $ORIGINAL_BRANCH`
   4. If QA cannot run (no server, no browser available), note "QA skipped — no running app detected" instead
   5. Include results under `## QA Results` in the output

Read `~/.agents/skills/review/output-format.md` and format the final output.
