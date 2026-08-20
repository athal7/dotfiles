---
description: Audit the OMP agent system against observed behavior and measured data
---

Audit the agent system against its configured OMP behavior and measured OMP/AOE data.

$ARGUMENTS

When arguments name a specific topic, audit only that topic. A bare `/audit` covers the full system.

1. Read the relevant OMP configuration, system prompt, skills, and recent OMP session plan and task state before collecting telemetry.
2. Use `aoe status --json`, `aoe ps --json`, and `aoe list --json` for session status, dispatch cadence, and worktree usage. Treat AOE as the session-dispatch source of truth.
3. Use OMP session JSONL files under `~/.omp/agent/sessions/` for per-message telemetry. Filter by the requested window using file modification time, tolerate unreadable files and unknown record types, and report only fields actually present in the documented schema.
4. Measure skill loads, interrupted sessions, model/token/cost usage, and command or tool failures where the transcript exposes them. Report unavailable dimensions as `not_available`, never as zero.
5. Sample recent sessions to verify that required skills loaded, review findings were grounded in diffs, remote writes showed full content for approval, and scheduled sessions did not stop at plan mode.
6. Report each requirement with the measured evidence, known gaps, and one concrete remediation per finding. Do not change configuration or make remote writes as part of this command.
