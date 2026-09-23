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
  send)
    ;;
  *)
    exit 64
    ;;
esac
EOF
cat >"$BIN/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$BIN/aoe" "$BIN/sleep"
CHECKER="$REPO_ROOT/dot_local/bin/executable_check-error-logs"
PROMPT="$REPO_ROOT/dot_agents/prompts/fix-launchagent-errors.md"
chmod +x "$CHECKER"

printf 'Error: session changed while launch hooks were running\n' >"$LOG_DIR/aoe-old.error.log"
log_size=$(stat -f%z "$LOG_DIR/aoe-old.error.log")
printf '%s:%s\n' "$LOG_DIR/aoe-old.error.log" 0 >"$LOG_DIR/.check-error-logs-state"

run_checker() {
  HOME="$HOME_DIR" \
    PATH="$BIN:/usr/bin:/bin" \
    AOE_TEST_LOG="$AOE_LOG" \
    AOE_TEST_MODE="${AOE_TEST_MODE:-success}" \
    "$CHECKER" "$PROMPT"
}

: >"$AOE_LOG"
output=$(run_checker)
printf '%s\n' "$output" | grep -F 'Dispatched LaunchAgent triage prompt'
add_call=$(sed -n '/^add /p' "$AOE_LOG")
case "$add_call" in
  "add $HOME_DIR/code/dotfiles --title "*) ;;
  *) exit 1 ;;
esac
grep -F 'session start test-session' "$AOE_LOG" >/dev/null
grep -F 'send --no-revive test-session Triage the supplied LaunchAgent error-log lines' "$AOE_LOG" >/dev/null
grep -F 'Services with new errors: aoe-old' "$AOE_LOG" >/dev/null
grep -F '[aoe-old] Error: session changed while launch hooks were running' "$AOE_LOG" >/dev/null
grep -Fqx "$LOG_DIR/aoe-old.error.log:$log_size" "$LOG_DIR/.check-error-logs-state"

printf '%s\n' 'Error: another launch failure' >>"$LOG_DIR/aoe-old.error.log"
AOE_TEST_MODE=fail-start
export AOE_TEST_MODE
: >"$AOE_LOG"
output=$(run_checker)
printf '%s\n' "$output" | grep -F 'WARNING: dispatch failed'
state_after_failure=$(grep -F "$LOG_DIR/aoe-old.error.log:" "$LOG_DIR/.check-error-logs-state")
expected_state="$LOG_DIR/aoe-old.error.log:$log_size"
[[ "$state_after_failure" == "$expected_state" ]]
if grep -F 'send --no-revive' "$AOE_LOG"; then
  exit 1
fi

printf 'check-error-logs dispatcher test passed\n'
