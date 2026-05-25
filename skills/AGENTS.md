# Agent Instructions — Editing Skills

## Two kinds of skills

**Integration skills** document how to use a specific external tool or API — non-obvious flags, auth gotchas, silent failure modes. They may (and should) name the tool, show CLI commands, and reference binary names directly.

**Workflow skills** describe how to carry out a process. They are tool-agnostic by design: the body describes actions in plain language, never referencing tool names, binary names, CLI flags, or other skill names.

**When using any CLI tool, read `--help` first.** Run `<binary> --help` and `<binary> <subcommand> --help` before issuing commands. Integration skills document only what help text won't tell you — silent failures, wrong-output traps, and non-obvious cross-command dependencies. Everything else is in `--help`.

## Skill injection

Skills discover related skills through injection mappings configured in `opencode.json`'s `skill-inject` plugin. When a skill loads, the plugin appends references to the configured skills — no frontmatter declarations needed.

The mapping is explicit: `"review": ["qa", "gh", "linear", "code-quality"]` means loading the `review` skill also surfaces those four skills. This works for any installed skill, including external ones.

To wire a new dependency: add an entry to the plugin config. To swap a provider (e.g., replace `gh` with a GitLab skill): change the config, not the skill.

## Coupling violations

A **coupling violation** is any reference in a workflow skill body (or its included sub-files) to:

- A CLI binary name: `gh`, `git`, `linear`, `sqlite3`, `opencode`, `jq`, `curl`, etc.
- A specific skill name: `` `load the slack skill` ``, `` `the architecture skill` ``
- An MCP tool name: `context7`, `webfetch` (when used as a named tool, not a concept)
- A platform-specific term as a noun: "pull request", "PR" (use "merge request" or "code review request")

**These are always violations in workflow skill bodies**, regardless of how reasonable they seem in context.

**These are never violations** in integration skill bodies or their sub-files — that's exactly where tool-specific content belongs.

### Examples

| Violation | Fix |
|---|---|
| `` `gh pr view`, `gh pr diff` `` | describe the action: "fetch the diff", "list open review threads" |
| `gh api graphql -f query='...'` | describe the action: "query for review threads" |
| `context7` (in workflow body) | "look up the library documentation" |
| "PR", "pull request" (in workflow body) | "merge request" or "code review request" |

## Adding a skill

1. Determine: integration or workflow?
2. If workflow: the body describes actions in plain language — never reference tools, binaries, or other skills.
3. If integration: tool-specific content is expected and correct.
4. Add injection entries in `opencode.json`'s `skill-inject` plugin config for any skill that should see this one (and vice versa).
5. Run `agentskills validate` on the skill directory.

## API skills describe shape, not code

When a skill documents a remote API, describe request and response shape — endpoints, request body structure, response field paths, gotchas. Don't embed code examples showing how to call the API or process its response. The injected HTTP client skill handles request mechanics; the agent already knows how to process JSON. CLI-flag usage (e.g., `gh --jq`) is part of the tool's own interface and is fine.

Auth lines use generic `$VARIABLE` format (e.g., `$SLACK_USER_TOKEN`). Whether the variable comes from an env var, Keychain, or another source is handled by the injected secrets skill — the API skill doesn't need to know.

## Don't expose machine-specific configuration

This is a public repository. Skill bodies must not hard-code values that are configured per-workspace in an external system: template names, project names, team keys, channel names, account IDs, internal URLs, or anything that's a label inside someone's tool. These vary by user and won't apply to anyone else who clones this repo.

Instead, teach the agent how to *discover* the values at runtime — show the query, command, or config file that surfaces them, so each user sees their own. Examples that need this treatment: list templates via the integration's API, read repo-level template files (`.github/ISSUE_TEMPLATE/`), check workspace config (`.linear.toml`, `orgs.<org>.*`).

If the value is a true public constant of the tool (a documented endpoint URL, a stable command name, a published vocabulary term), it can be hard-coded.

## Editing an existing skill

**Before adding any content to a workflow skill**, scan the section you're editing for existing violations and fix them. Do not add new content that would introduce a violation.

After editing, re-read the full body of the skill and ask: "If this skill were used with a different tool provider, would this line still make sense?" If not, it's a violation.

## Sub-files

Sub-files (`.md` files referenced from a SKILL.md) inherit the type of their parent skill. A sub-file of a workflow skill is also a workflow skill and must follow the same rules. A sub-file of an integration skill may contain tool-specific content.

## When something shouldn't be a skill

Before writing a skill, ask what the trigger looks like. Three patterns map to three primitives, only one of them being a skill:

| Trigger pattern | Right primitive | Example |
|---|---|---|
| Continuous — applies to every session of some kind | Instructions file (`opencode.json`'s `instructions:` array) | TDD: every code-change session, write the failing test first. Lives in `dot_config/opencode/tdd.md`, always loaded. |
| Mode-restricted — needs different tool/skill access than the default agent | Built-in or custom agent + `permission` config | Plan: read-only deliberation. Built-in plan agent (Tab) with its own skill allow-list. Build agent denies the deliberation skills. |
| Concrete moment — fires at a specific, named point in a workflow | Skill (SKILL.md) | Commit, push, review, qa — each has a clear trigger ("about to commit"). |

Signs you're building the wrong primitive:

- "This skill should fire on every code change." → it's an instructions file, not a skill.
- "Build agent shouldn't see this skill." → use `permission.skill` deny on build, not a skill body that tells the agent when to skip.
- "This skill orchestrates several other skills." → see the orchestrator failure section below.

When the data shows a skill is underperforming its trigger (low load rate when the moment clearly happened), the fix is usually relocating to the right primitive, not redesigning the skill description.

## Skill shape — lessons from the orchestrator failure

A previous "process" skill declared ten required capabilities and an eight-phase workflow. Measured across 69 sessions: TDD compliance fell from 34% to 9%, and architecture capability loading fell from 26% to 7%, **when the orchestrator was loaded vs. not**. The orchestrator actively suppressed the capabilities it wrapped.

The rules below are the generalized lessons — follow them when creating or editing any skill.

### One skill = one trigger = one moment of action

A skill should fire at a specific, concrete moment. If you find yourself writing "Phase 1… Phase 2… Phase 3…" or "After step N, also do X," you are building an orchestrator. Split instead.

Signs a skill is becoming an orchestrator:
- A single skill covers multiple distinct moments in a workflow (e.g., one that governs both pre-commit and post-commit behavior)
- Step N of the skill says "do this other thing from a different skill"

Split rule: **split by when the skill fires, not by what topic it covers.** Two skills that both cover "git stuff" but fire at different moments (commit-time vs. push-time) are correctly separate. One skill that covers "commit and format conventions" is correctly one skill because both fire at commit-time.

### Agents read long phase graphs as menus

A long workflow skill is not read as imperatives — it is read as a list the agent skim-selects from. The action phases (implement, commit, push) get executed; the deliberative phases (plan, verify, capture) get skipped. This is why the process skill suppressed TDD — TDD was mentioned inside a phase list, not as a standing imperative. The fix that worked: TDD became an always-loaded instructions file, not a skill at all.

Corollary: short, standalone skills with concrete triggers outperform long skills with phase graphs, even when the long skill formally lists the same dependencies.

### Indirection beyond one hop is not followed

Measured: sub-files referenced from a parent skill were loaded in 4% of sessions that loaded the parent. A skill body that says "read this other file and follow the instructions there" will lose ~90% of the intended behavior at each hop. Keep the concrete action in the skill that fires, not one hop away.

### Skills that work share a shape

Skills measured with high adoption (commit 57%, push similar) all have:
- A clear, concrete trigger (a specific moment, not a general topic)
- Imperative steps, not descriptive phases
- <80 lines in the main body
- No chained dependencies that the agent must load additional skills to satisfy the described behavior

**`conversations` is the workflow-skill success case** — 3% session load with a phase-graph-shaped body of four sources (KB, meetings, chat, email). It works because the trigger is concrete ("research a person/decision") and the body is a *decision tree*, not a phase graph. The agent enters at one of four entry points based on the question; it doesn't read top-to-bottom executing each phase. When writing a workflow skill that needs to cover multiple sources or paths, prefer decision-tree structure (here's the question, here's where to go) over phase structure (do this, then this, then this).

### Measure before refactoring a skill

If a skill feels wrong, query the session DB at `~/.local/share/opencode/opencode.db` for actual loading and capability-use patterns before redesigning. Designing skill ontologies in the abstract reproduces the orchestrator failure.
