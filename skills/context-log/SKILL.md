---
name: context-log
description: Create and update .opencode/context-log.md to preserve issue context and checkpoint history across compaction and session handoffs
license: MIT
compatibility: opencode
metadata:
  provides:
    - context-log
---

## Purpose

Preserve incremental context across:
- Long sessions (review/QA need to understand what changed)
- Compaction (history gets summarized, log persists)
- Handoffs (another agent can pick up where you left off)

## Location

`.opencode/context-log.md` in project root (created if missing).

## When to Update

| Event | Action |
|-------|--------|
| Session start | Create with issue context |
| After each commit | Append checkpoint |
| On compaction | Reference log instead of re-summarizing |

## Initial Template

```markdown
# Context Log

## Issue
- **Key**: PROJ-123
- **Title**: Add password reset flow
- **Acceptance Criteria**:
  - User can request reset via email
  - Token expires after 24h
  - Rate limited to 3 requests/hour

## Checkpoints
```

## Checkpoint Template

```markdown
### [timestamp] commit-sha-short
- **Intent**: What this commit accomplishes
- **Tests**: green/red, which ones
- **Next**: What to do next
```

## On Compaction

Don't re-summarize. Just say:
> See `.opencode/context-log.md` for issue context and build history.
