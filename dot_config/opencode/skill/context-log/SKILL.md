---
name: context-log
description: Maintaining .opencode/context-log.md for session continuity
---

## Purpose

The context log preserves incremental context across:
- Long sessions (Review/QA need to understand what changed)
- Compaction (history gets summarized, log persists)
- Handoffs (another agent can pick up where you left off)

## Location

`.opencode/context-log.md` in project root (created if missing)

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

## Example Checkpoint

```markdown
### 2024-01-15 14:30 abc1234
- **Intent**: Add token generation and email service
- **Tests**: green (token_test.rb), red (rate_limit_test.rb - not implemented yet)
- **Next**: Implement rate limiting middleware
```

## On Compaction

Don't re-summarize. Just say:
> See `.opencode/context-log.md` for issue context and build history.
