---
name: review
description: Review changes [commit|branch|merge-request|staged] — verifies your own work before shipping, or reviews someone else's code with inline comments and approval
license: MIT
compatibility: opencode
metadata:
  provides:
    - verify
    - code-review
  requires:
    - qa
    - source-control
---

Fetch the diff based on input, then follow all instructions below.

- **No arguments**: `git diff` + `git diff --cached` + `git status --short`, then `git diff origin/<default>...HEAD`
- **`staged`** (or **`pre-commit`**): `git diff --cached` only
- **Commit hash**: `git show <hash>`
- **Branch name**: `git diff <branch>...HEAD`
- **Merge request URL/number**: use your `source-control` capability to fetch the diff and metadata

**Merge request rules:**
- "Review this merge request" means analyze and draft a written review — do NOT submit or implement fixes unless explicitly asked.
- When a merge request has reviews and conflicts, use merge (not rebase) to resolve them — rebasing invalidates existing review comments.
- Show the full proposed review and ask "Do you approve?" before submitting. Then STOP and wait for explicit approval.
- **Inline-first:** post findings as inline comments only via your `source-control` capability. Do NOT include verdict, TL;DR, or summaries in the submitted body — those are session output only. The only exception is a review-wide observation that genuinely cannot be attributed to any line.

**If reviewing a merge request** (URL or number provided): check out the branch locally before proceeding using your `source-control` capability. Save the original branch so you can restore it after. If local checkout is not possible, fall back to fetching diff and metadata via your `source-control` capability.

---

## Phase 1: Context & Static Analysis

Read `~/.agents/skills/review/context-gathering.md` and follow all steps (issue context, prior review history, project rules, static analysis pass).

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
4. Prior review summary (merge request only; omit if not a merge request review)

**Extended context (add to each specialist's prompt):**
- **Project rules** — full text of AGENTS.md, CONVENTIONS.md, etc. — for **all** agents
- **Issue context** — requirements, acceptance criteria, project goals — for correctness, completeness, maintainability only; write "No issue context available" if none found
- **Prior reviews** — full prior review summary — for **all** agents (merge request only)

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
<prior review summary or 'N/A — not a merge request review'>
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

2. **Runtime verification**:

   **Start the dev server** — auto-detect the command in this priority order:
   - `package.json` → `scripts.dev`, then `scripts.start`
   - `Procfile` → the `web:` entry
   - `Makefile` → a `dev`, `serve`, or `start` target
   - `README.md` → look for a "Getting started" / "Running locally" code block

   Spawn in the background via your `shell` capability. Wait up to 15 seconds for a "listening on" / "ready" / port-bound log line. Record the session ID and local URL for QA.

   - **Merge request reviews**: always attempt server start. If no command found, note "QA skipped — could not detect dev server command".
   - **Branch / staged / commit reviews**: only if the diff modifies views, templates, controllers, frontend code, or UI interactions. If no server can be started, note "QA skipped — no running app detected".

   Steps:
   1. Use the `qa` capability — pass context about which flows changed and the local URL
   2. Kill the background server session and restore the original branch
   3. Include results under `## QA Results` in the output

Read `~/.agents/skills/review/output-format.md` and format the final output.
