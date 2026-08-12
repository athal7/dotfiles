---
name: elasticsearch
description: Load when investigating production errors, latency, or trace data — triage order, index patterns, field names, and time-range syntax. Use before hand-rolling a query DSL call or guessing field names.
license: MIT
---

Query application logs, APM traces, and errors via the Elasticsearch REST API. Endpoint `$ES_URL` varies per environment.

## Triage order

State the hypothesis, bound the time window, and identify the scope (one service / one endpoint / one user / system-wide) before querying anything. Write down what a "confirmed" answer looks like — otherwise absence of evidence reads as evidence of absence.

**Don't start with logs.** Work coarse to fine: error/rate spike (is it real?) → APM traces (which transaction) → APM errors (root-cause code path) → logs (raw context). `trace.id` links all three indices — pull it from an error or slow trace, then `{"term": {"trace.id": "<id>"}}` for the surrounding logs.

| Symptom | Look first |
|---|---|
| Slow page loads | Traces, sort `transaction.duration.us` desc |
| 500s spiking | Errors, group by `error.grouping_key` |
| One user affected | Logs, filter by user/session id |
| Periodic | Logs, time pattern in `@timestamp` |
| After a deploy | Errors, filter `@timestamp` after deploy |

**Escalate** rather than keep digging when: error rate stays above baseline >15min with no identified cause · a trace shows an external dependency timing out · errors reference a migration or schema change · you need production access you don't have.

## Time range syntax

Pass `time_range` as a string like `15m`, `1h`, `24h`, `7d`. Translates to `now-{value}{unit}` in ES range filters.

## Query logs

Search application logs. Index: `logs-*`. Sorted by `@timestamp` desc.

```
POST logs-*/_search
```
```json
{"query":{"bool":{"must":[{"query_string":{"query":"YOUR LUCENE QUERY HERE"}},{"range":{"@timestamp":{"gte":"now-1h"}}}]}},"_source":["@timestamp","message","log.level","service.name","trace.id"],"sort":[{"@timestamp":"desc"}],"size":100}
```
Response fields: `.hits.hits[]._source` — extract `@timestamp`, `log.level`, `service.name`, `message`.

Add a service filter by inserting a `term` clause into the `must` array:
```json
{"term": {"service.name": "my-service"}}
```

## Query APM traces

Find slow transactions. Index: `traces-apm*`. Sorted by duration desc.

```
POST traces-apm*/_search
```
```json
{"query":{"bool":{"must":[{"range":{"@timestamp":{"gte":"now-1h"}}},{"range":{"transaction.duration.us":{"gte":500000}}}]}},"_source":["@timestamp","service.name","transaction.name","transaction.duration.us","transaction.result","trace.id"],"sort":[{"transaction.duration.us":"desc"}],"size":50}
```
Response fields: `.hits.hits[]._source` — extract `@timestamp`, `service.name`, `transaction.name`, `transaction.duration.us` (microseconds), `transaction.result`.

## Query APM errors

Find exceptions and error groups. Index: `logs-apm.error-*`. Sorted by `@timestamp` desc.

```
POST logs-apm.error-*/_search
```
```json
{"query":{"bool":{"must":[{"exists":{"field":"error.exception"}},{"range":{"@timestamp":{"gte":"now-1h"}}}]}},"_source":["@timestamp","error.exception.type","error.exception.message","error.grouping_key","service.name","transaction.name"],"sort":[{"@timestamp":"desc"}],"size":50}
```
Response fields: `.hits.hits[]._source` — extract `@timestamp`, `error.exception.type`, `error.exception.message`, `service.name`.

## Tips

- `query_string` uses Lucene syntax: `error AND timeout`, `level:ERROR`, `message:"connection refused"`
- To count by service: append `,"aggs":{"by_svc":{"terms":{"field":"service.name","size":10}}}` to the query JSON and read `.aggregations.by_svc.buckets`
- `trace.id` links logs ↔ traces ↔ errors across indices

## Kibana Dashboard API Gotchas

- **`PUT /api/saved_objects/dashboard/:id` replaces ALL attributes.** Read the full object first, modify only `panelsJSON`, and write everything back including `controlGroupInput`, `optionsJSON`, etc. Omitting any attribute silently breaks panels.
- **`PUT /api/saved_objects/index-pattern/:id` wipes the `fields` attribute** if you only set `title`/`timeFieldName`. To recreate safely, delete and use `POST /api/data_views/data_view` which auto-discovers fields.
- **Inline Lens panels referencing an `index-pattern` saved object render blank if that object is corrupted.** The resilient pattern is `adHocDataViews` + `internalReferences` inside `embeddableConfig.attributes.state` — self-contained, no external saved-object dependency.
- **ES transform `_update` cannot change `pivot`.** Must stop, delete, recreate. If the dest index has historical data from rolled-over source indices, check `_snapshot` first.
