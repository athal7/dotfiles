---
description: Audit the OMP agent system against observed behavior and measured data
---

Audit the agent system against its configured OMP behavior and measured OMP/AOE data.

$ARGUMENTS

When arguments name a specific topic, audit only that topic. A bare `/audit` covers the full system. When no duration is specified, use a seven-day telemetry window.

1. Read the deployed OMP configuration, system prompt, relevant skill bodies, and recent OMP session plan and task state before collecting telemetry. Compare source configuration only where it owns the deployed value.
2. Use `aoe status --json`, `aoe ps --json`, and `aoe list --json` for session status, dispatch cadence, and worktree usage. Treat AOE as the session-dispatch source of truth.
3. For every scheduled AOE session, read `~/.local/state/aoe/omp-session-map/<aoe-session-id>.json`. Match its `correlationId` to the exact `AOE_CORRELATION=` token in an OMP JSONL user message. Report `matched`, `mapping_missing`, `transcript_missing`, or `correlation_ambiguous`. Do not infer a match from title, path, or time alone.
4. Use OMP session JSONL files under `~/.omp/agent/sessions/` for per-message telemetry. Filter by the requested window using file modification time. Tolerate unreadable files and unknown record types. Report only fields present in the documented schema.
5. Measure skill loads, session exits, interrupted responses, model and tool failures, and cost usage where the transcript exposes them. Keep assistant-message usage and `model_usage` records separate. Report recorded cost without assigning a currency when the schema has none.
6. Read the deployed permission policy. Report `tools.approvalMode`, tool-level approvals, shell pattern approvals, and commands captured by a final wildcard allow rule. For remote writes, report only transcript evidence that the exact payload was displayed and an explicit approval occurred. Report unavailable dimensions as `not_available`, never as zero.
7. Sample recent sessions to verify required skills loaded, review findings were grounded in diffs, remote writes showed full content for approval, and scheduled sessions did not stop at plan mode.
8. Report each requirement with measured evidence, known gaps, and one concrete remediation per finding. Do not change configuration or make remote writes as part of this command.
