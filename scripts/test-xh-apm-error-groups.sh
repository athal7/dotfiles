#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/xh-apm-error-groups.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/bin"
cat >"$WORK/bin/xh-es-search" <<'STUB'
#!/bin/sh
[ "$#" -eq 1 ] && [ "$1" = 'logs-apm.error-*' ] || exit 64
cat "$FIXTURE"
STUB
cat >"$WORK/bin/chezmoi" <<'STUB'
#!/bin/sh
[ "$#" -eq 3 ] && [ "$1" = data ] && [ "$2" = '--format' ] && [ "$3" = json ] || exit 64
printf '{"prod_services":{"svc-a":"repo-a","svc-b":"repo-b","svc-c":"repo-c"}}\n'
STUB
chmod +x "$WORK/bin/xh-es-search" "$WORK/bin/chezmoi"

cat >"$WORK/valid.json" <<'JSON'
{"timed_out":false,"_shards":{"total":1,"successful":1,"skipped":0,"failed":0},"hits":{"total":{"value":8,"relation":"eq"},"hits":[]},"aggregations":{"services":{"doc_count_error_upper_bound":0,"sum_other_doc_count":0,"buckets":[{"key":"svc-b","doc_count":4,"groups":{"doc_count_error_upper_bound":0,"sum_other_doc_count":0,"buckets":[{"key":"group-b","doc_count":4,"sample":{"hits":{"hits":[{"_source":{"service.name":"svc-b","error.grouping_key":"group-b","error.exception.type":"TypeB","error.exception.message":"message B","trace.id":"trace-b","stacktrace":"MUST_NOT_LEAK"}}]}}}]}},{"key":"unmapped","doc_count":2,"groups":{"doc_count_error_upper_bound":0,"sum_other_doc_count":0,"buckets":[{"key":"group-x","doc_count":2,"sample":{"hits":{"hits":[{"_source":{"service.name":"unmapped","error.grouping_key":"group-x","error.exception.type":"TypeX","error.exception.message":"message X","trace.id":"trace-x"}}]}}}]}},{"key":"svc-a","doc_count":2,"groups":{"doc_count_error_upper_bound":0,"sum_other_doc_count":0,"buckets":[{"key":"group-a","doc_count":2,"sample":{"hits":{"hits":[{"_source":{"service.name":"svc-a","error.grouping_key":"group-a","error.exception.type":"TypeA","error.exception.message":"message A","trace.id":"trace-a"}}]}}}]}}]}}}
JSON

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
run() { PATH="$WORK/bin:$PATH" FIXTURE="$WORK/input.json" "$ROOT/dot_local/bin/executable_xh-apm-error-groups"; }
expect_fail() {
  local name=$1
  if run >"$WORK/out" 2>"$WORK/err"; then bad "$name fails closed"; else
    if [[ ! -s "$WORK/out" ]]; then ok "$name fails closed without JSON evidence"; else bad "$name emits no evidence on failure"; fi
  fi
}

cp "$WORK/valid.json" "$WORK/input.json"
if output=$(run 2>"$WORK/err"); then
  if jq -e '.total == 8 and (.selected|length)==2 and .selected[0].service=="svc-b" and .selected[0].repository=="repo-b" and .selected[0].trace_id=="trace-b" and .highest_unmapped.service=="unmapped"' <<<"$output" >/dev/null && ! grep -q 'MUST_NOT_LEAK' <<<"$output"; then ok "returns mapped and highest-unmapped compact evidence"; else bad "returns mapped and highest-unmapped compact evidence"; fi
else bad "valid mapped/unmapped response accepted"; fi

jq ' .hits.total.value=0 | .aggregations.services.buckets=[]' "$WORK/valid.json" >"$WORK/input.json"
if output=$(run 2>"$WORK/err") && jq -e ' .window=="now-24h..now" and .total==0 and .selected==[] and .highest_unmapped==null' <<<"$output" >/dev/null; then ok "valid zero hits returns an empty evidence result"; else bad "valid zero hits returns an empty evidence result"; fi

cp "$WORK/valid.json" "$WORK/input.json"
jq '.timed_out=true' "$WORK/input.json" >"$WORK/tmp" && mv "$WORK/tmp" "$WORK/input.json"
expect_fail "timed out query"
jq '.timed_out=false | ._shards.failed=1' "$WORK/valid.json" >"$WORK/input.json"
expect_fail "shard failure"
jq '.aggregations.services.sum_other_doc_count=1' "$WORK/valid.json" >"$WORK/input.json"
expect_fail "truncated service buckets"
jq '.aggregations.services.buckets[0].groups.doc_count_error_upper_bound=1' "$WORK/valid.json" >"$WORK/input.json"
expect_fail "inexact grouping counts"
jq 'del(.aggregations.services)' "$WORK/valid.json" >"$WORK/input.json"
expect_fail "missing aggregations"
jq '.aggregations.services.buckets[0].groups.buckets[0].sample.hits.hits[0]._source["service.name"]="wrong"' "$WORK/valid.json" >"$WORK/input.json"
expect_fail "sample identity mismatch"
jq 'del(.aggregations.services.buckets[0].groups.buckets[0].sample.hits.hits[0]._source["trace.id"])' "$WORK/valid.json" >"$WORK/input.json"
expect_fail "missing trace ID"
printf '{"error":{"reason":"private source details"}}\n' >"$WORK/input.json"
expect_fail "Elasticsearch error"
if ! grep -q 'private source details' "$WORK/err"; then ok "does not leak source response details"; else bad "does not leak source response details"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
