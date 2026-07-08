#!/usr/bin/env bash
# Functional tests for aoe-cmd. Plain bash, no bats. Stubs the `aoe` binary
# (via a temp bin dir prepended to PATH) so tests don't touch the real aoe
# daemon or tmux.
#
#   scripts/test-aoe-cmd.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AOE_CMD="$REPO_ROOT/dot_local/bin/executable_aoe-cmd"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aoe-cmd-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0; fail=0
ok()   { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad()  { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (want '$3' got '$2')"; fi; }

# Fake `aoe` binary: records every invocation (one line per call, tab-joined
# args) to $AOE_LOG, then behaves per the AOE_STUB_* env vars so each test
# can control `aoe add` / `aoe acp prompt` outcomes independently.
STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/aoe" <<'STUB'
#!/bin/sh
{ IFS='	'; echo "$*" >> "$AOE_LOG"; }
if [ "$1" = "add" ]; then
  [ -n "${AOE_STUB_ADD_OUTPUT:-}" ] && printf '%s\n' "$AOE_STUB_ADD_OUTPUT"
  exit "${AOE_STUB_ADD_EXIT:-0}"
elif [ "$1" = "acp" ] && [ "$2" = "prompt" ]; then
  exit "${AOE_STUB_PROMPT_EXIT:-0}"
fi
echo "fake aoe: unexpected invocation: $*" >&2
exit 99
STUB
chmod +x "$STUB_BIN/aoe"

AOE_LOG="$WORK/aoe.log"

run_aoe_cmd() {
  : > "$AOE_LOG"
  PATH="$STUB_BIN:$PATH" AOE_LOG="$AOE_LOG" \
    AOE_STUB_ADD_OUTPUT="${AOE_STUB_ADD_OUTPUT:-}" \
    AOE_STUB_ADD_EXIT="${AOE_STUB_ADD_EXIT:-0}" \
    AOE_STUB_PROMPT_EXIT="${AOE_STUB_PROMPT_EXIT:-0}" \
    sh "$AOE_CMD" "$@"
}

canonical_add_output='✓ Added session: audit-20260101-000000
  Profile: main
  Path:    /tmp/proj
  ID:      24777d8e72f2416c
'

# ---------------------------------------------------------------------------
echo "== usage validation =="

test_missing_args() {
  local out status
  out="$(run_aoe_cmd -d /tmp/proj -n audit 2>&1)" && status=0 || status=$?
  check "missing MESSAGE exits non-zero" "$status" 1
  if printf '%s' "$out" | grep -qi 'usage'; then ok "missing MESSAGE prints usage"; else bad "missing MESSAGE prints usage (got: $out)"; fi

  out="$(run_aoe_cmd -n audit /audit 2>&1)" && status=0 || status=$?
  check "missing -d exits non-zero" "$status" 1

  out="$(run_aoe_cmd -d /tmp/proj /audit 2>&1)" && status=0 || status=$?
  check "missing -n exits non-zero" "$status" 1
}
test_missing_args

# ---------------------------------------------------------------------------
echo "== happy path =="

test_happy_path() {
  local status
  AOE_STUB_ADD_OUTPUT="$canonical_add_output" \
    run_aoe_cmd -d /tmp/proj -n audit /audit >/dev/null 2>&1 && status=0 || status=$?
  check "exits 0 on success" "$status" 0

  local add_line prompt_line
  add_line="$(grep '^add' "$AOE_LOG")"
  prompt_line="$(grep '^acp' "$AOE_LOG")"

  case "$add_line" in
    *"add	/tmp/proj	--agent	opencode	--title	audit-"*) ok "aoe add called with --agent opencode and prefixed title" ;;
    *) bad "aoe add args (got: $add_line)" ;;
  esac

  case "$add_line" in
    *"--title	audit-"[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]*) ok "title has YYYYMMDD-HHMMSS timestamp suffix" ;;
    *) bad "title timestamp suffix (got: $add_line)" ;;
  esac

  check "aoe acp prompt called with parsed ID and message" "$prompt_line" "acp	prompt	24777d8e72f2416c	/audit"
}
test_happy_path

# ---------------------------------------------------------------------------
echo "== aoe add failure =="

test_add_failure() {
  local out status
  out="$(AOE_STUB_ADD_EXIT=1 AOE_STUB_ADD_OUTPUT="" run_aoe_cmd -d /tmp/proj -n audit /audit 2>&1)" && status=0 || status=$?
  check "exits non-zero when aoe add fails" "$status" 1
  if grep -qc '^acp' "$AOE_LOG"; then bad "acp prompt should not be called when add fails"; else ok "acp prompt not called when add fails"; fi
}
test_add_failure

# ---------------------------------------------------------------------------
echo "== unparseable ID =="

test_unparseable_id() {
  local out status
  out="$(AOE_STUB_ADD_OUTPUT='✓ Added session: audit-x
  Profile: main' run_aoe_cmd -d /tmp/proj -n audit /audit 2>&1)" && status=0 || status=$?
  check "exits non-zero when ID cannot be parsed" "$status" 1
  if grep -qc '^acp' "$AOE_LOG"; then bad "acp prompt should not be called when ID missing"; else ok "acp prompt not called when ID missing"; fi
}
test_unparseable_id

# ---------------------------------------------------------------------------
echo "== aoe acp prompt failure =="

test_prompt_failure() {
  local out status
  out="$(AOE_STUB_ADD_OUTPUT="$canonical_add_output" AOE_STUB_PROMPT_EXIT=1 \
    run_aoe_cmd -d /tmp/proj -n audit /audit 2>&1)" && status=0 || status=$?
  check "exits non-zero when aoe acp prompt fails" "$status" 1
}
test_prompt_failure

# ---------------------------------------------------------------------------
echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
