#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-error-logs-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

HOME_DIR="$WORK/home"
BIN="$WORK/bin"
LOG_DIR="$HOME_DIR/Library/Logs"
AOE_LOG="$WORK/aoe.log"
mkdir -p "$BIN" "$LOG_DIR" "$HOME_DIR/code/dotfiles"

cat >"$BIN/aoe" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$AOE_TEST_LOG"
case "$1" in
  add)
    printf 'ID: test-session\n'
    ;;
  session)
    [[ "${AOE_TEST_MODE:-success}" != fail-start ]]
    ;;
  *)
    exit 64
    ;;
esac
EOF
ln -s "$REPO_ROOT/dot_local/bin/executable_aoe-scheduled-session" "$BIN/aoe-scheduled-session"
chmod +x "$BIN/aoe"
CHECKER="$REPO_ROOT/dot_local/bin/executable_check-error-logs"
PROMPT="$REPO_ROOT/dot_agents/prompts/fix-launchagent-errors.md"
chmod +x "$CHECKER"

printf 'Error: session changed while launch hooks were running\n' >"$LOG_DIR/aoe-old.error.log"
log_size=$(stat -f%z "$LOG_DIR/aoe-old.error.log")
printf '%s:%s\n' "$LOG_DIR/aoe-old.error.log" 0 >"$LOG_DIR/.check-error-logs-state"
printf '%s\n' \
  '[10/12/2026, 9:15:54 AM] [homebridge-google-nest-sdm] Plugin initialization failed, there was a failure with event subscription. Did you read the readme: https://github.com/potmat/homebridge-google-nest-sdm#where-do-the-config-values-come-from ChannelError: Failed to connect to channel. Reason: Failed to connect before the deadline' \
  "  details: 'Failed to connect before the deadline'," \
  >"$LOG_DIR/homebridge.error.log"
homebridge_log_size=$(stat -f%z "$LOG_DIR/homebridge.error.log")
printf '%s:%s\n' "$LOG_DIR/homebridge.error.log" 0 >>"$LOG_DIR/.check-error-logs-state"

run_checker() {
  HOME="$HOME_DIR" \
    PATH="$BIN:/usr/bin:/bin" \
    AOE_TEST_LOG="$AOE_LOG" \
    AOE_BIN="$BIN/aoe" \
    AOE_TEST_MODE="${AOE_TEST_MODE:-success}" \
    "$CHECKER" "$PROMPT"
}

: >"$AOE_LOG"
output=$(run_checker)
printf '%s\n' "$output" | grep -F 'Dispatched LaunchAgent triage prompt'
python3 - "$AOE_LOG" <<'PY'
import pathlib, sys
body = pathlib.Path(sys.argv[1]).read_text()
assert "Triage the supplied LaunchAgent error-log lines" in body
assert "Services with new errors: aoe-old" in body
assert "[aoe-old] Error: session changed while launch hooks were running" in body
assert "[homebridge]" not in body
PY
grep -Fqx "$LOG_DIR/aoe-old.error.log:$log_size" "$LOG_DIR/.check-error-logs-state"
grep -Fqx "$LOG_DIR/homebridge.error.log:$homebridge_log_size" "$LOG_DIR/.check-error-logs-state"

printf '%s\n' \
  '[10/13/2026, 9:15:54 AM] [homebridge-google-nest-sdm] Plugin initialization failed, there was a failure with event subscription. Did you read the readme: https://github.com/potmat/homebridge-google-nest-sdm#where-do-the-config-values-come-from ChannelError: Failed to connect to channel. Reason: Permission denied' \
  >>"$LOG_DIR/homebridge.error.log"

printf '%s\n' 'Error: another launch failure' >>"$LOG_DIR/aoe-old.error.log"
AOE_TEST_MODE=fail-start
export AOE_TEST_MODE
: >"$AOE_LOG"
output=$(run_checker)
printf '%s\n' "$output" | grep -F 'WARNING: dispatch failed'
state_after_failure=$(grep -F "$LOG_DIR/aoe-old.error.log:" "$LOG_DIR/.check-error-logs-state")
expected_state="$LOG_DIR/aoe-old.error.log:$log_size"
[[ "$state_after_failure" == "$expected_state" ]]
python3 - "$AOE_LOG" <<'PY'
import pathlib, sys
body = pathlib.Path(sys.argv[1]).read_text()
assert "Services with new errors: aoe-old,homebridge" in body
assert "[homebridge] [10/13/2026, 9:15:54 AM] [homebridge-google-nest-sdm] Plugin initialization failed" in body
PY
grep -Fqx "$LOG_DIR/homebridge.error.log:$homebridge_log_size" "$LOG_DIR/.check-error-logs-state"
grep -F 'ID: test-session' "$LOG_DIR/.check-error-logs-pending" >/dev/null
: >"$AOE_LOG"
output=$(run_checker)
printf '%s\n' "$output" | grep -F 'previous dispatch requires reconciliation'
[[ ! -s "$AOE_LOG" ]]

printf 'check-error-logs dispatcher test passed\n'
