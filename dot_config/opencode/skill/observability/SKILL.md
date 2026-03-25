---
name: observability
description: Query Elasticsearch logs, APM traces, and errors via curl — index patterns, field names, and time-range syntax
---

Query application logs, APM traces, and errors using the Elasticsearch REST API directly.

Auth is via environment variables loaded by direnv:
- `ES_URL` — base URL (e.g. `https://elasticsearch.example.com`)
- `ES_API_KEY` — API key for the `Authorization: ApiKey` header

## Time range syntax

Pass `time_range` as a string like `15m`, `1h`, `24h`, `7d`. Translates to `now-{value}{unit}` in ES range filters.

## Query logs

Search application logs. Index: `logs-*`. Sorted by `@timestamp` desc.

```bash
ES_QUERY='{"query":{"bool":{"must":[{"query_string":{"query":"YOUR LUCENE QUERY HERE"}},{"range":{"@timestamp":{"gte":"now-1h"}}}]}},"_source":["@timestamp","message","log.level","service.name","trace.id"],"sort":[{"@timestamp":"desc"}],"size":100}'

curl -s -X POST "$ES_URL/logs-*/_search" \
  -H "Authorization: ApiKey $ES_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$ES_QUERY" \
  | jq '.hits.hits[]._source | {ts: .["@timestamp"], level: .["log.level"], svc: .["service.name"], msg: .message}'
```

Add a service filter by inserting a `term` clause into the `must` array:
```json
{"term": {"service.name": "my-service"}}
```

## Query APM traces

Find slow transactions. Index: `traces-apm*`. Sorted by duration desc.

```bash
# min_duration_ms converts to microseconds: 500ms → 500000us
MIN_US=500000

ES_QUERY="{\"query\":{\"bool\":{\"must\":[{\"range\":{\"@timestamp\":{\"gte\":\"now-1h\"}}},{\"range\":{\"transaction.duration.us\":{\"gte\":$MIN_US}}}]}},\"_source\":[\"@timestamp\",\"service.name\",\"transaction.name\",\"transaction.duration.us\",\"transaction.result\",\"trace.id\"],\"sort\":[{\"transaction.duration.us\":\"desc\"}],\"size\":50}"

curl -s -X POST "$ES_URL/traces-apm*/_search" \
  -H "Authorization: ApiKey $ES_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$ES_QUERY" \
  | jq '.hits.hits[]._source | {ts: .["@timestamp"], svc: .["service.name"], tx: .["transaction.name"], ms: (.["transaction.duration.us"] / 1000 | round), result: .["transaction.result"]}'
```

## Query APM errors

Find exceptions and error groups. Index: `logs-apm.error-*`. Sorted by `@timestamp` desc.

```bash
ES_QUERY='{"query":{"bool":{"must":[{"exists":{"field":"error.exception"}},{"range":{"@timestamp":{"gte":"now-1h"}}}]}},"_source":["@timestamp","error.exception.type","error.exception.message","error.grouping_key","service.name","transaction.name"],"sort":[{"@timestamp":"desc"}],"size":50}'

curl -s -X POST "$ES_URL/logs-apm.error-*/_search" \
  -H "Authorization: ApiKey $ES_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$ES_QUERY" \
  | jq '.hits.hits[]._source | {ts: .["@timestamp"], svc: .["service.name"], type: .["error.exception.type"], msg: .["error.exception.message"]}'
```

## Tips

- `query_string` uses Lucene syntax: `error AND timeout`, `level:ERROR`, `message:"connection refused"`
- To count by service: append `,"aggs":{"by_svc":{"terms":{"field":"service.name","size":10}}}` and read `.aggregations.by_svc.buckets`
- `trace.id` links logs ↔ traces ↔ errors across indices
- If `$ES_API_KEY` is missing, check `~/.env` is loaded (`direnv allow`)
