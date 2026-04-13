# Agent Instructions — Editing Skills

## Integration vs Workflow

**Integration skills** expose how to use a specific external tool or API when `--help` isn't enough — non-obvious flags, auth gotchas, silent failure modes.

**Workflow skills** describe how to carry out a process. They declare `requires` in metadata when they depend on capabilities. They reference capabilities by name in their body — never hardcode specific skill names, CLI binary names, or tool references.

**CLI providers** — when a tool has comprehensive `--help`, map the capability to `cli://<binary>` in `capabilities.yaml` instead of writing a wrapper skill. The agent reads `--help` on demand. Only write a skill when there are genuine gotchas that help text won't surface.

## The mechanism: `requires` + manifest

The manifest (`~/.agents/capabilities.yaml`) is the registry. It maps capability names to providers — a skill name, `cli://<binary>`, or `mcp://<server>`.

Workflow skills declare what they need:

```yaml
# Workflow skill
metadata:
  requires:
    - pull-requests
    - qa
    - issues
```

`requires` is a YAML list of capability names — **no colons, no defaults**.

`provides` is optional author metadata — useful for discoverability but not part of the resolution mechanism. The manifest is authoritative, not skill frontmatter.

## Adding a skill

1. Determine: integration or workflow?
2. If workflow, add `requires` listing the capabilities it needs
3. In the skill body, reference capabilities — not specific skill, CLI, or tool names
4. Add a manifest entry in `~/.agents/capabilities.yaml` if the capability isn't already mapped
5. Run `agentskills` to validate

## Auditing a skill

Look for hardcoded tool or skill names in the body of workflow skills — these are coupling violations. Replace with capability references so the skill remains tool-agnostic.

Example: `load the slack skill` → `use your `chat` capability`
