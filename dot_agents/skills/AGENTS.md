# Agent Instructions — Editing Skills

## Two kinds of skills

**Integration skills** document how to use a specific external tool or API — non-obvious flags, auth gotchas, silent failure modes. They may (and should) name the tool, show CLI commands, and reference binary names directly. They declare `provides` in metadata.

**Workflow skills** describe how to carry out a process. They are tool-agnostic by design: they declare `requires` in metadata and reference only capability names in their body — never tool names, binary names, CLI flags, or other skill names.

**CLI providers** — when a tool has comprehensive `--help`, map the capability to `cli://<binary>` in `capabilities.yaml` instead of writing a wrapper skill. Only write an integration skill when there are genuine gotchas that help text won't surface.

**When using any CLI capability, read `--help` first.** Run `<binary> --help` and `<binary> <subcommand> --help` before issuing commands. Integration skills document only what help text won't tell you — silent failures, wrong-output traps, and non-obvious cross-command dependencies. Everything else is in `--help`.

**For short gotchas (1-3 sentences), use the `notes` field in `capabilities.yaml` instead of a skill file.** The manifest supports an extended map form:

```yaml
# flat form — no gotchas
issues: cli://linear

# extended form — with notes
calendar:
  provider: cli://ical
  notes: "Timestamps in JSON output are UTC — always convert to local before displaying."
```

Use a skill file when the guidance needs examples, command references, or spans more than a few sentences. Use `notes` for single silent-failure facts.

## The mechanism: `requires` + manifest

The manifest (`~/.agents/capabilities.yaml`) is the registry. It maps capability names to providers — a skill name, `cli://<binary>`, or `mcp://<server>`.

Workflow skills declare what they need:

```yaml
metadata:
  requires:
    - code-review
    - issues
    - ci
```

`requires` is a YAML list of capability names — **no colons, no defaults**.

`provides` is optional author metadata for discoverability. The manifest is authoritative, not skill frontmatter.

## Capability naming

Capability names must be **provider-agnostic** — they name the domain, not the tool.

| Good (domain) | Bad (tool-specific) |
|---|---|
| `code-review` | `pull-requests`, `github-prs` |
| `issues` | `linear-issues`, `jira` |
| `calendar` | `ical`, `gcal` |
| `chat` | `slack` |
| `ci` | `github-actions` |

If the name would only make sense with one specific tool, it's wrong.

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
| `` `gh pr view`, `gh pr diff` `` | `use your \`code-review\` capability` |
| `gh api graphql -f query='...'` | `use your \`code-review\` capability` |
| `load the \`plan\` skill` | `use your \`plan\` capability` |
| `the \`architecture\` skill Section 2` | `the \`architecture\` capability Section 2` |
| `via \`gq\`` | remove — capability reference is sufficient |
| `` `gh repo view --json visibility` `` | `use your \`code-review\` capability` |
| `context7` (in workflow body) | `your documentation lookup capability` |
| "PR", "pull request" (in workflow body) | "merge request" or "code review request" |

## Adding a skill

1. Determine: integration or workflow?
2. If workflow:
   - Add `requires` listing the capabilities it needs
   - In the body, reference only capability names — never tools, binaries, or other skills
   - Name capabilities after domains, not tools
   - Add a manifest entry in `dot_agents/capabilities.yaml` if the capability isn't already mapped
3. If integration:
   - Add `provides` listing the capability name(s) this skill implements
   - Tool-specific content is expected and correct here
4. Run `agentskills validate` on the skill directory

## Deleting a skill or sub-file

Some skills in `~/.agents/skills/` are **externally managed** via `.chezmoiexternal.toml.tmpl` (e.g. `ical-cli`, `linear-cli`). Do not delete or modify those — chezmoi owns them; remove the external entry instead.

For source-managed skills, use `chezmoi destroy` — see the repo-level `AGENTS.md` for the general deletion pattern.

## Editing an existing skill

**Before adding any content to a workflow skill**, scan the section you're editing for existing violations and fix them. Do not add new content that would introduce a violation.

After editing, re-read the full body of the skill and ask: "If this skill were used with a different tool provider, would this line still make sense?" If not, it's a violation.

## Sub-files

Sub-files (`.md` files referenced from a SKILL.md) inherit the type of their parent skill. A sub-file of a workflow skill is also a workflow skill and must follow the same rules. A sub-file of an integration skill may contain tool-specific content.

## Skill shape — lessons from the orchestrator failure

A previous "process" skill declared ten required capabilities and an eight-phase workflow. Measured across 69 sessions: TDD compliance fell from 34% to 9%, and architecture capability loading fell from 26% to 7%, **when the orchestrator was loaded vs. not**. The orchestrator actively suppressed the capabilities it wrapped.

The rules below are the generalized lessons — follow them when creating or editing any skill.

### One skill = one trigger = one moment of action

A skill should fire at a specific, concrete moment. If you find yourself writing "Phase 1… Phase 2… Phase 3…" or "After step N, also do X," you are building an orchestrator. Split instead.

Signs a skill is becoming an orchestrator:
- A single skill covers multiple distinct moments in a workflow (e.g., "plan" that also governs commit-time behavior)
- `provides` lists more than one capability whose triggers fire at different times
- Step N of the skill says "do this other thing from a different capability"

Split rule: **split by when the skill fires, not by what topic it covers.** Two skills that both cover "git stuff" but fire at different moments (commit-time vs. push-time) are correctly separate. One skill that covers "commit and format conventions" is correctly one skill because both fire at commit-time.

### Agents read long phase graphs as menus

A long workflow skill is not read as imperatives — it is read as a list the agent skim-selects from. The action phases (implement, commit, push) get executed; the deliberative phases (plan, verify, capture) get skipped. This is why the process skill suppressed TDD — TDD was mentioned inside a phase list, not as a standing imperative.

Corollary: short, standalone skills with concrete triggers outperform long skills with phase graphs, even when the long skill formally `requires` the same capabilities.

### Indirection beyond one hop is not followed

Measured: sub-files referenced from a parent skill were loaded in 4% of sessions that loaded the parent. A skill body that says "read this other file and follow the instructions there" or "load your X capability and then load your Y capability" will lose ~90% of the intended behavior at each hop. Keep the concrete action in the skill that fires, not one hop away.

### Skills that work share a shape

Skills measured with high adoption (commit 57%, push similar) all have:
- A clear, concrete trigger (a specific moment, not a general topic)
- Imperative steps, not descriptive phases
- <80 lines in the main body
- No chained `requires` that the agent must load additional skills to satisfy the described behavior

### Measure before refactoring a skill

If a skill feels wrong, query the session DB at `~/.local/share/opencode/opencode.db` for actual loading and capability-use patterns before redesigning. Designing skill ontologies in the abstract reproduces the orchestrator failure.
