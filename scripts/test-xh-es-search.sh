#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="$REPO_ROOT/dot_local/bin/executable_xh-es-search"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/xh-es-search-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/bin"

cat > "$WORK/bin/xh" <<'STUB'
#!/bin/sh
printf '%s\n' "$@" > "$XH_LOG"
STUB
cat > "$WORK/bin/chezmoi" <<'STUB'
#!/bin/sh
[ "$1" = data ] && [ "$2" = --format=json ] || exit 64
printf '%s\n' "${CHEZMOI_DATA:-}"
STUB
chmod +x "$WORK/bin/xh" "$WORK/bin/chezmoi"
command -v jq >/dev/null 2>&1 || { printf 'jq is required for this test\n' >&2; exit 1; }

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

run_valid() {
  : > "$WORK/xh.log"
  PATH="$WORK/bin:$PATH" XH_LOG="$WORK/xh.log" \
    ES_URL="https://es.example/" PAYLOAD='{"size":0}' \
    sh "$WRAPPER" 'logs-apm.error-*'
}

expect_rejected() {
  name=$1
  shift
  local es_url="${TEST_ES_URL-https://es.example}"
  local payload="${TEST_PAYLOAD-'{"size":0}'}"
  : > "$WORK/xh.log"
  if PATH="$WORK/bin:$PATH" XH_LOG="$WORK/xh.log" \
    ES_URL="$es_url" PAYLOAD="$payload" \
    sh "$WRAPPER" "$@" >/dev/null 2>&1; then
    bad "$name exits non-zero"
    return
  fi
  if [ -s "$WORK/xh.log" ]; then
    bad "$name does not invoke xh"
  else
    ok "$name"
  fi
}
run_host_fallback() {
  : > "$WORK/xh.log"
  env -u ES_URL PATH="$WORK/bin:$PATH" XH_LOG="$WORK/xh.log" \
    CHEZMOI_DATA='{"esHost":"es.example"}' PAYLOAD='{"size":0}' \
    sh "$WRAPPER" 'logs-apm.error-*'
}

expect_host_rejected() {
  name=$1
  data=$2
  : > "$WORK/xh.log"
  if env -u ES_URL PATH="$WORK/bin:$PATH" XH_LOG="$WORK/xh.log" \
    CHEZMOI_DATA="$data" PAYLOAD='{"size":0}' \
    sh "$WRAPPER" 'logs-apm.error-*' >/dev/null 2>&1; then
    bad "$name exits non-zero"
    return
  fi
  if [ -s "$WORK/xh.log" ]; then
    bad "$name does not invoke xh"
  else
    ok "$name"
  fi
}

expected='--ignore-stdin
--session-read-only=agent
POST
https://es.example/logs-apm.error-*/_search
Content-Type:application/json
--raw
{"size":0}'

run_valid
actual="$(cat "$WORK/xh.log")"
if [ "$actual" = "$expected" ]; then
  ok "constructs the fixed read-only search request"
else
  bad "constructs the fixed read-only search request"
  printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual"
fi

run_host_fallback
actual="$(cat "$WORK/xh.log")"
if [ "$actual" = "$expected" ]; then
  ok "derives the read-only endpoint from chezmoi esHost"
else
  bad "derives the read-only endpoint from chezmoi esHost"
  printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual"
fi

expect_host_rejected "missing chezmoi esHost" '{}'
expect_host_rejected "invalid chezmoi esHost" '{"esHost":"../other"}'
expect_host_rejected "leading dash in chezmoi esHost" '{"esHost":"-leading"}'

CHEZMOI_DATA='not json' run_valid
actual="$(cat "$WORK/xh.log")"
if [ "$actual" = "$expected" ]; then
  ok "explicit ES_URL overrides chezmoi data"
else
  bad "explicit ES_URL overrides chezmoi data"
fi

expect_rejected "missing index"
expect_rejected "extra argument" 'logs-*' 'Authorization:Bearer'
expect_rejected "slash in index" 'logs-*/_bulk'
expect_rejected "space in index" 'logs-* other'
expect_rejected "leading dash" '--help'
TEST_ES_URL='' expect_rejected "missing ES_URL" 'logs-*'
TEST_PAYLOAD='' expect_rejected "missing PAYLOAD" 'logs-*'

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
