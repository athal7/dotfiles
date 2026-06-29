---
name: openspec
priority: 0
authoritative_for: [implement-work, design-decisions, rejected-alternatives]
description: OpenSpec durable store — authoritative source for /implement work; read BEFORE other collectors to build the session exclusion set
---

## Why priority 0

This collector runs first. Its primary job is building the **session exclusion set** used by the `opencode` collector — a list of worktree paths whose sessions are already covered by an archived OpenSpec change and should not get a redundant (token-expensive) transcript read.

## How to query

For each date being enriched, read every `$KB_ROOT/openspec/*/changes/archive/<date>-*/kb-meta.yaml`. Collect the `worktree:` value from each. That set is the exclusion list passed to the `opencode` collector.

```bash
# Collect worktrees for a given date
for meta in $KB_ROOT/openspec/*/changes/archive/<date>-*/kb-meta.yaml; do
  grep '^worktree:' "$meta" | awk '{print $2}'
done
```

Then read each archived change's `design.md`:

```
$KB_ROOT/openspec/*/changes/archive/<date>-*/design.md
```

READ these (do not copy them — the artifacts are already in the KB via the symlink). Extract decisions, the "why", and rejected alternatives for the decisions log.

Also read the durable `specs/` for standing requirements:

```
$KB_ROOT/openspec/*/specs/
```

## What to extract

- Decisions, rationale, and rejected alternatives from `design.md` files
- The set of worktree paths (→ exclusion list for the `opencode` collector)

## What to skip

- Re-narrating or duplicating the full design content in the journal — reference the durable store artifacts instead
