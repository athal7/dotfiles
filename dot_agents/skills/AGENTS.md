# Agent Instructions — Editing Skills

## Integration vs Workflow

**Integration skills** expose how to use a specific external tool or API. They declare `provides` in metadata, listing the capabilities they offer.

**Workflow skills** describe how to carry out a process. They declare `requires` in metadata when they depend on capabilities from integration (or other) skills. They reference capabilities by name in their body — never hardcode specific skill names.

## provides/requires convention

```yaml
# Integration skill
metadata:
  provides:
    - post-message
    - search-messages

# Workflow skill
metadata:
  requires:
    - pull-requests
    - qa
    - issues
```

`requires` is a YAML list of capability names — **no colons, no defaults**. Defaults for capability resolution live in `~/.agents/capabilities.yaml`, not in skill frontmatter.

## Adding a skill

1. Determine: integration or workflow?
2. Add `provides` (integration) or `requires` (workflow) to the `metadata` block accordingly
3. In the skill body, reference capabilities — not specific skill or tool names
4. Run `agentskills` to validate

## Auditing a skill

Look for hardcoded tool or skill names in the body of workflow skills — these are coupling violations. Replace with capability references so the skill remains tool-agnostic.

Example: `load the slack skill` → `use the search-messages capability`
