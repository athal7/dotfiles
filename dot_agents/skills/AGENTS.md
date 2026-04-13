# Agent Instructions — Editing Skills

## Two kinds of skills

**Integration skills** document how to use a specific external tool or API — non-obvious flags, auth gotchas, silent failure modes. They may (and should) name the tool, show CLI commands, and reference binary names directly. They declare `provides` in metadata.

**Workflow skills** describe how to carry out a process. They are tool-agnostic by design: they declare `requires` in metadata and reference only capability names in their body — never tool names, binary names, CLI flags, or other skill names.

**CLI providers** — when a tool has comprehensive `--help`, map the capability to `cli://<binary>` in `capabilities.yaml` instead of writing a wrapper skill. Only write an integration skill when there are genuine gotchas that help text won't surface.

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
| `load the \`process\` skill` | `use your \`process\` capability` |
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

## Editing an existing skill

**Before adding any content to a workflow skill**, scan the section you're editing for existing violations and fix them. Do not add new content that would introduce a violation.

After editing, re-read the full body of the skill and ask: "If this skill were used with a different tool provider, would this line still make sense?" If not, it's a violation.

## Sub-files

Sub-files (`.md` files referenced from a SKILL.md) inherit the type of their parent skill. A sub-file of a workflow skill is also a workflow skill and must follow the same rules. A sub-file of an integration skill may contain tool-specific content.
