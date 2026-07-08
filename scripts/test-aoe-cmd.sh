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
# can control `aoe add` / `aoe session start` / `aoe send` outcomes
# independently.
STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/aoe" <<'STUB'
#!/bin/sh
{ IFS='	'; echo "$*" >> "$AOE_LOG"; }
if [ "$1" = "add" ]; then
  [ -n "${AOE_STUB_ADD_OUTPUT:-}" ] && printf '%s\n' "$AOE_STUB_ADD_OUTPUT"
  exit "${AOE_STUB_ADD_EXIT:-0}"
elif [ "$1" = "session" ] && [ "$2" = "start" ]; then
  [ -n "${AOE_STUB_SESSION_START_EXIT:-0}" ] && [ "${AOE_STUB_SESSION_START_EXIT:-0}" != "0" ] && \
    echo "fake aoe: session start failing on purpose" >&2
  exit "${AOE_STUB_SESSION_START_EXIT:-0}"
elif [ "$1" = "send" ]; then
  [ -n "${AOE_STUB_SEND_EXIT:-0}" ] && [ "${AOE_STUB_SEND_EXIT:-0}" != "0" ] && \
    echo "fake aoe: send failing on purpose" >&2
  exit "${AOE_STUB_SEND_EXIT:-0}"
fi
echo "fake aoe: unexpected invocation: $*" >&2
exit 99
STUB
chmod +x "$STUB_BIN/aoe"

AOE_LOG="$WORK/aoe.log"

run_aoe_cmd() {
  : > "$AOE_LOG"
  PATH="$STUB_BIN:$PATH" AOE_LOG="$AOE_LOG" \
    AOE_CMD_STARTUP_SLEEP="${AOE_CMD_STARTUP_SLEEP:-0}" \
    AOE_STUB_ADD_OUTPUT="${AOE_STUB_ADD_OUTPUT:-}" \
    AOE_STUB_ADD_EXIT="${AOE_STUB_ADD_EXIT:-0}" \
    AOE_STUB_SESSION_START_EXIT="${AOE_STUB_SESSION_START_EXIT:-0}" \
    AOE_STUB_SEND_EXIT="${AOE_STUB_SEND_EXIT:-0}" \
    sh "$AOE_CMD" "$@"
}

send_call_count() {
  grep -c '^send' "$AOE_LOG"
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

  local add_line session_start_line send_line
  add_line="$(grep '^add' "$AOE_LOG")"
  session_start_line="$(grep '^session' "$AOE_LOG")"
  send_line="$(grep '^send' "$AOE_LOG")"

  case "$add_line" in
    *"add	/tmp/proj	--tool	opencode	--title	audit-"*) ok "aoe add called with --tool opencode (no -l) and prefixed title" ;;
    *) bad "aoe add args (got: $add_line)" ;;
  esac

  case "$add_line" in
    *"-l"*) bad "aoe add should not be called with -l (got: $add_line)" ;;
    *) ok "aoe add called without -l" ;;
  esac

  case "$add_line" in
    *"--title	audit-"[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]*) ok "title has YYYYMMDD-HHMMSS timestamp suffix" ;;
    *) bad "title timestamp suffix (got: $add_line)" ;;
  esac

  check "aoe session start called with parsed ID" "$session_start_line" "session	start	24777d8e72f2416c"
  # Trailing space is intentional: it dismisses opencode's TUI slash-command
  # autocomplete dropdown before aoe send's Enter keystroke, so slash-command
  # messages (all 4 real scheduled jobs) actually submit. See executable_aoe-cmd.
  check "aoe send called with parsed ID and message plus trailing space" "$send_line" "send	24777d8e72f2416c	/audit "

  local add_lineno session_start_lineno send_lineno
  add_lineno="$(grep -n '^add' "$AOE_LOG" | cut -d: -f1)"
  session_start_lineno="$(grep -n '^session' "$AOE_LOG" | cut -d: -f1)"
  send_lineno="$(grep -n '^send' "$AOE_LOG" | cut -d: -f1)"
  if [ "$add_lineno" -lt "$session_start_lineno" ] && [ "$session_start_lineno" -lt "$send_lineno" ]; then
    ok "aoe add, session start, send called in order"
  else
    bad "aoe add, session start, send call order (got log: $(cat "$AOE_LOG"))"
  fi
}
test_happy_path

# ---------------------------------------------------------------------------
echo "== aoe add failure =="

test_add_failure() {
  local out status
  out="$(AOE_STUB_ADD_EXIT=1 AOE_STUB_ADD_OUTPUT="" run_aoe_cmd -d /tmp/proj -n audit /audit 2>&1)" && status=0 || status=$?
  check "exits non-zero when aoe add fails" "$status" 1
  if grep -qc '^send' "$AOE_LOG"; then bad "aoe send should not be called when add fails"; else ok "aoe send not called when add fails"; fi
}
test_add_failure

# ---------------------------------------------------------------------------
echo "== unparseable ID =="

test_unparseable_id() {
  local out status
  out="$(AOE_STUB_ADD_OUTPUT='✓ Added session: audit-x
  Profile: main' run_aoe_cmd -d /tmp/proj -n audit /audit 2>&1)" && status=0 || status=$?
  check "exits non-zero when ID cannot be parsed" "$status" 1
  if grep -qc '^send' "$AOE_LOG"; then bad "aoe send should not be called when ID missing"; else ok "aoe send not called when ID missing"; fi
}
test_unparseable_id

# ---------------------------------------------------------------------------
echo "== aoe session start failure =="

test_session_start_failure() {
  local out status
  out="$(AOE_STUB_ADD_OUTPUT="$canonical_add_output" AOE_STUB_SESSION_START_EXIT=1 \
    run_aoe_cmd -d /tmp/proj -n audit /audit 2>&1)" && status=0 || status=$?
  check "exits non-zero when aoe session start fails" "$status" 1
  if grep -qc '^send' "$AOE_LOG"; then bad "aoe send should not be called when session start fails"; else ok "aoe send not called when session start fails"; fi
  if printf '%s' "$out" | grep -q "'aoe session start' failed for session"; then
    ok "prints fail-loud message with session title/id"
  else
    bad "prints fail-loud message with session title/id (got: $out)"
  fi
}
test_session_start_failure

# ---------------------------------------------------------------------------
echo "== aoe send failure =="

test_send_failure() {
  local out status
  out="$(AOE_STUB_ADD_OUTPUT="$canonical_add_output" AOE_STUB_SEND_EXIT=1 \
    run_aoe_cmd -d /tmp/proj -n audit /audit 2>&1)" && status=0 || status=$?
  check "exits non-zero when aoe send fails" "$status" 1
  check "aoe send called exactly once" "$(send_call_count)" 1
  if printf '%s' "$out" | grep -q "'aoe send' failed for session"; then
    ok "prints fail-loud message with session title/id"
  else
    bad "prints fail-loud message with session title/id (got: $out)"
  fi
}
test_send_failure

# ---------------------------------------------------------------------------
echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
