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
# args) to $AOE_LOG, and the value of AGENT_OF_EMPIRES_PROFILE seen at call
# time (one line per call, in the same order — line N of $AOE_ENV_LOG
# corresponds to line N of $AOE_LOG) to $AOE_ENV_LOG, so tests can assert
# aoe-cmd's `-p PROFILE` handling reaches every `aoe` invocation without
# disturbing the existing arg-based assertions on $AOE_LOG. Then behaves per
# the AOE_STUB_* env vars so each test can control `aoe add` / `aoe session
# start` / `aoe send` outcomes independently.
STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"
cat > "$STUB_BIN/aoe" <<'STUB'
#!/bin/sh
{ IFS='	'; echo "$*" >> "$AOE_LOG"; }
printf '%s\n' "${AGENT_OF_EMPIRES_PROFILE:-}" >> "$AOE_ENV_LOG"
if [ "$1" = "add" ]; then
  [ -n "${AOE_STUB_ADD_OUTPUT:-}" ] && printf '%s\n' "$AOE_STUB_ADD_OUTPUT"
  exit "${AOE_STUB_ADD_EXIT:-0}"
elif [ "$1" = "session" ] && [ "$2" = "start" ]; then
  [ -n "${AOE_STUB_SESSION_START_EXIT:-0}" ] && [ "${AOE_STUB_SESSION_START_EXIT:-0}" != "0" ] && \
    echo "fake aoe: session start failing on purpose" >&2
  exit "${AOE_STUB_SESSION_START_EXIT:-0}"
elif [ "$1" = "session" ] && [ "$2" = "capture" ]; then
  printf '%s\n' "${AOE_STUB_CAPTURE_OUTPUT:-Ask anything...}"
  exit 0
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
AOE_ENV_LOG="$WORK/aoe-env.log"

run_aoe_cmd() {
  : > "$AOE_LOG"
  : > "$AOE_ENV_LOG"
  PATH="$STUB_BIN:$PATH" AOE_LOG="$AOE_LOG" AOE_ENV_LOG="$AOE_ENV_LOG" \
    AOE_CMD_READY_TIMEOUT="${AOE_CMD_READY_TIMEOUT:-5}" \
    AOE_CMD_POLL_INTERVAL="${AOE_CMD_POLL_INTERVAL:-0}" \
    AOE_STUB_ADD_OUTPUT="${AOE_STUB_ADD_OUTPUT:-}" \
    AOE_STUB_ADD_EXIT="${AOE_STUB_ADD_EXIT:-0}" \
    AOE_STUB_SESSION_START_EXIT="${AOE_STUB_SESSION_START_EXIT:-0}" \
    AOE_STUB_CAPTURE_OUTPUT="${AOE_STUB_CAPTURE_OUTPUT:-Ask anything...}" \
    AOE_STUB_SEND_EXIT="${AOE_STUB_SEND_EXIT:-0}" \
    sh "$AOE_CMD" "$@"
}

send_call_count() {
  grep -c '^send' "$AOE_LOG"
}

# Variant of run_aoe_cmd that keeps stdout and stderr split, for assertions
# that need to check stdout specifically (the relayed `aoe add` output).
# Writes stdout to $1 and stderr to $2; returns aoe-cmd's exit status.
run_aoe_cmd_split() {
  local stdout_file="$1" stderr_file="$2"
  shift 2
  : > "$AOE_LOG"
  : > "$AOE_ENV_LOG"
  PATH="$STUB_BIN:$PATH" AOE_LOG="$AOE_LOG" AOE_ENV_LOG="$AOE_ENV_LOG" \
    AOE_CMD_READY_TIMEOUT="${AOE_CMD_READY_TIMEOUT:-5}" \
    AOE_CMD_POLL_INTERVAL="${AOE_CMD_POLL_INTERVAL:-0}" \
    AOE_STUB_ADD_OUTPUT="${AOE_STUB_ADD_OUTPUT:-}" \
    AOE_STUB_ADD_EXIT="${AOE_STUB_ADD_EXIT:-0}" \
    AOE_STUB_SESSION_START_EXIT="${AOE_STUB_SESSION_START_EXIT:-0}" \
    AOE_STUB_CAPTURE_OUTPUT="${AOE_STUB_CAPTURE_OUTPUT:-Ask anything...}" \
    AOE_STUB_SEND_EXIT="${AOE_STUB_SEND_EXIT:-0}" \
    sh "$AOE_CMD" "$@" > "$stdout_file" 2> "$stderr_file"
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
  # Anchor on the "start" subcommand specifically — "session capture" lines
  # (from the readiness poll) also start with "session" and would otherwise
  # match too.
  session_start_line="$(grep '^session\tstart' "$AOE_LOG")"
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
    *"--worktree"*) bad "aoe add should not be called with --worktree when -w is unset (got: $add_line)" ;;
    *) ok "aoe add called without --worktree when -w is unset" ;;
  esac

  case "$add_line" in
    *"--new-branch"*) bad "aoe add should not be called with --new-branch when -b is unset (got: $add_line)" ;;
    *) ok "aoe add called without --new-branch when -b is unset" ;;
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

  local add_lineno session_start_lineno capture_lineno send_lineno
  add_lineno="$(grep -n '^add' "$AOE_LOG" | cut -d: -f1)"
  session_start_lineno="$(grep -n '^session\tstart' "$AOE_LOG" | cut -d: -f1)"
  capture_lineno="$(grep -n '^session\tcapture' "$AOE_LOG" | head -1 | cut -d: -f1)"
  send_lineno="$(grep -n '^send' "$AOE_LOG" | cut -d: -f1)"
  if [ "$add_lineno" -lt "$session_start_lineno" ] && \
     [ "$session_start_lineno" -lt "$capture_lineno" ] && \
     [ "$capture_lineno" -lt "$send_lineno" ]; then
    ok "aoe add, session start, capture poll, send called in order"
  else
    bad "aoe add, session start, capture poll, send call order (got log: $(cat "$AOE_LOG"))"
  fi
}
test_happy_path

# ---------------------------------------------------------------------------
echo "== worktree/new-branch passthrough =="

test_worktree_passthrough() {
  local status add_line
  AOE_STUB_ADD_OUTPUT="$canonical_add_output" \
    run_aoe_cmd -d /tmp/proj -n audit -w "fix/apm-20260101-audit" -b /audit >/dev/null 2>&1 && status=0 || status=$?
  check "exits 0 on success with -w/-b" "$status" 0

  add_line="$(grep '^add' "$AOE_LOG")"

  case "$add_line" in
    *"--tool	opencode	--title	audit-"*) ok "aoe add still called with --tool opencode and prefixed title when -w/-b set" ;;
    *) bad "aoe add args with -w/-b (got: $add_line)" ;;
  esac

  case "$add_line" in
    *"--worktree	fix/apm-20260101-audit"*) ok "aoe add called with --worktree BRANCH" ;;
    *) bad "aoe add --worktree passthrough (got: $add_line)" ;;
  esac

  case "$add_line" in
    *"--new-branch"*) ok "aoe add called with --new-branch" ;;
    *) bad "aoe add --new-branch passthrough (got: $add_line)" ;;
  esac
}
test_worktree_passthrough

# ---------------------------------------------------------------------------
echo "== stdout relay of aoe add output =="

test_stdout_relay_happy_path() {
  local status out_file err_file
  out_file="$WORK/stdout.happy"
  err_file="$WORK/stderr.happy"
  AOE_STUB_ADD_OUTPUT="$canonical_add_output" \
    run_aoe_cmd_split "$out_file" "$err_file" -d /tmp/proj -n audit /audit && status=0 || status=$?
  check "exits 0 on success" "$status" 0

  if grep -q 'ID:      24777d8e72f2416c' "$out_file" && grep -q 'Path:    /tmp/proj' "$out_file"; then
    ok "stdout contains relayed aoe add output (ID + Path)"
  else
    bad "stdout contains relayed aoe add output (got: $(cat "$out_file"))"
  fi
}
test_stdout_relay_happy_path

test_stdout_relay_on_ready_timeout() {
  local status out_file err_file
  out_file="$WORK/stdout.timeout"
  err_file="$WORK/stderr.timeout"
  AOE_STUB_ADD_OUTPUT="$canonical_add_output" \
    AOE_STUB_CAPTURE_OUTPUT="booting..." \
    AOE_CMD_READY_TIMEOUT=1 AOE_CMD_POLL_INTERVAL=0 \
    run_aoe_cmd_split "$out_file" "$err_file" -d /tmp/proj -n audit /audit && status=0 || status=$?
  check "exits non-zero when TUI never becomes ready" "$status" 1

  if grep -q 'ID:      24777d8e72f2416c' "$out_file"; then
    ok "stdout still contains relayed aoe add ID even when readiness poll times out"
  else
    bad "stdout still contains relayed aoe add ID on timeout (got: $(cat "$out_file"))"
  fi

  if grep -q "never became ready" "$err_file"; then
    ok "stderr (not stdout) carries the never-became-ready diagnostic"
  else
    bad "stderr carries never-became-ready diagnostic (got: $(cat "$err_file"))"
  fi
}
test_stdout_relay_on_ready_timeout

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
echo "== readiness poll timeout =="

test_ready_timeout() {
  local out status
  out="$(AOE_STUB_ADD_OUTPUT="$canonical_add_output" \
    AOE_STUB_CAPTURE_OUTPUT="booting..." \
    AOE_CMD_READY_TIMEOUT=1 AOE_CMD_POLL_INTERVAL=0 \
    run_aoe_cmd -d /tmp/proj -n audit /audit 2>&1)" && status=0 || status=$?
  check "exits non-zero when TUI never becomes ready" "$status" 1
  if grep -qc '^send' "$AOE_LOG"; then bad "aoe send should not be called when TUI never ready"; else ok "aoe send not called when TUI never ready"; fi
  if printf '%s' "$out" | grep -q "never became ready"; then
    ok "prints never-became-ready message"
  else
    bad "prints never-became-ready message (got: $out)"
  fi
}
test_ready_timeout

# ---------------------------------------------------------------------------
echo "== profile flag (-p) =="

test_profile_flag_applies_to_every_aoe_call() {
  local status env_lines call_count
  AOE_STUB_ADD_OUTPUT="$canonical_add_output" \
    run_aoe_cmd -d /tmp/proj -n audit -p test-profile /audit >/dev/null 2>&1 && status=0 || status=$?
  check "exits 0 on success with -p" "$status" 0

  call_count="$(wc -l < "$AOE_LOG" | tr -d ' ')"
  env_lines="$(sort -u "$AOE_ENV_LOG")"
  check "AGENT_OF_EMPIRES_PROFILE is the only distinct value seen across all aoe calls" "$env_lines" "test-profile"

  local set_count
  set_count="$(grep -c '^test-profile$' "$AOE_ENV_LOG" || true)"
  check "every aoe call (add, session start, capture, send) saw the profile env var" "$set_count" "$call_count"
}
test_profile_flag_applies_to_every_aoe_call

test_no_profile_flag_leaves_env_unset_for_every_call() {
  local status call_count unset_count
  AOE_STUB_ADD_OUTPUT="$canonical_add_output" \
    run_aoe_cmd -d /tmp/proj -n audit /audit >/dev/null 2>&1 && status=0 || status=$?
  check "exits 0 on success without -p" "$status" 0

  call_count="$(wc -l < "$AOE_LOG" | tr -d ' ')"
  unset_count="$(grep -c '^$' "$AOE_ENV_LOG" || true)"
  check "AGENT_OF_EMPIRES_PROFILE stays unset for every aoe call when -p is omitted" "$unset_count" "$call_count"
}
test_no_profile_flag_leaves_env_unset_for_every_call

# ---------------------------------------------------------------------------
echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
