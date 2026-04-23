---
name: observability
description: Investigate production issues using logs, traces, and errors — how to triage, correlate signals, and know when to escalate. Load your logs capability for query syntax.
license: MIT
metadata:
  requires:
    - logs
---

Use this skill to investigate production problems. For query syntax, index patterns, and curl commands, use your `logs` capability.

## Triage process

Start with the symptom, not the tool. Before querying anything:

1. **State the hypothesis** — what do you think is wrong and why?
2. **Bound the time window** — when did it start? Is it ongoing or resolved?
3. **Identify the scope** — one service, one endpoint, one user, or system-wide?

This prevents aimless log-scrolling and makes findings interpretable.

## Signal hierarchy

Work top-down — coarser signals first, drill into finer ones only when needed:

| Signal | What it tells you | When to use |
|---|---|---|
| **Error rate / rate spike** | Something broke at scale | First check — confirms the problem is real |
| **APM traces** | Which transaction is slow or failing, full call chain | Once you know the scope |
| **APM errors** | Exception type, stack trace, grouping key | When you need the root cause code path |
| **Logs** | Raw context around a specific event | When traces don't have enough detail |

Don't start with logs. Start with traces or error groups, then use `trace.id` to pull the surrounding log context.

## Correlating signals

The `trace.id` field links all three indices (`logs-*`, `traces-apm*`, `logs-apm.error-*`). Once you have a `trace.id` from an error or slow trace, use it to pull all logs from that same request:

```json
{"term": {"trace.id": "<trace-id-here>"}}
```

## Asking the right questions

Before querying, write down what a "confirmed" answer looks like. Examples:

- "If query returns 0 errors for service X in the last 1h, the issue has resolved"
- "If the slow trace shows N+1 queries on endpoint Y, the cause is clear"
- "If errors spike at exactly :15 and :45 of every hour, it's likely a cron job"

This prevents misreading absence of evidence as evidence of absence.

## When to escalate

Stop investigating and escalate to the team when:

- Error rate is sustained above baseline for > 15 minutes and cause is not identified
- A trace shows calls to an external dependency timing out (not your code)
- Errors reference a data migration or schema change (potential data integrity issue)
- You've ruled out the obvious causes and need production access or context you don't have

## Common patterns

| Symptom | Where to look first |
|---|---|
| Slow page loads | APM traces — sort by `transaction.duration.us` desc |
| 500 errors spiking | APM errors — group by `error.grouping_key` |
| One user affected | Logs — filter by user ID or session ID |
| Periodic issue | Logs — look for time pattern in `@timestamp` |
| After a deploy | APM errors — filter by `@timestamp` after deploy time |
