---
name: elasticsearch
description: Query Elasticsearch logs, APM traces, and errors — index patterns, field names, auth setup, and time-range syntax
license: MIT
---

Query application logs, APM traces, and errors using the Elasticsearch REST API directly.

Endpoint: `$ES_URL` — base URL varies per environment.

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
