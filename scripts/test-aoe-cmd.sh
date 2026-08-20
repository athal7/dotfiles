#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AOE_CMD="$REPO_ROOT/dot_local/bin/executable_aoe-cmd"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aoe-cmd-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (want '$3' got '$2')"; fi; }

STUB_BIN="$WORK/bin"
TEST_HOME="$WORK/home"
AOE_LOG="$WORK/aoe.log"
mkdir -p "$STUB_BIN" "$TEST_HOME/.omp/agent"
printf 'modelRoles:\n  default: test-model\n' > "$TEST_HOME/.omp/agent/config.yml"

cat > "$STUB_BIN/aoe" <<'STUB'
#!/bin/sh
{ IFS='	'; echo "$*" >> "$AOE_LOG"; }
case "$1" in
  add)
    [ -n "${AOE_STUB_ADD_OUTPUT:-}" ] && printf '%s\n' "$AOE_STUB_ADD_OUTPUT"
    exit "${AOE_STUB_ADD_EXIT:-0}"
    ;;
  session)
    case "$2" in
      start)
        [ "${AOE_STUB_SESSION_START_EXIT:-0}" = 0 ] || echo "fake aoe: session start failing on purpose" >&2
        exit "${AOE_STUB_SESSION_START_EXIT:-0}"
        ;;
      capture)
        printf '%s\n' "${AOE_STUB_CAPTURE_OUTPUT:-⬢ test-model}"
        exit 0
        ;;
    esac
    ;;
  send)
    [ "${AOE_STUB_SEND_EXIT:-0}" = 0 ] || echo "fake aoe: send failing on purpose" >&2
    exit "${AOE_STUB_SEND_EXIT:-0}"
    ;;
esac
exit 99
STUB
chmod +x "$STUB_BIN/aoe"

run_aoe_cmd() {
  : > "$AOE_LOG"
  PATH="$STUB_BIN:$PATH" HOME="$TEST_HOME" AOE_LOG="$AOE_LOG" \
    AOE_CMD_READY_TIMEOUT="${AOE_CMD_READY_TIMEOUT:-5}" \
    AOE_CMD_POLL_INTERVAL="${AOE_CMD_POLL_INTERVAL:-0}" \
    AOE_STUB_ADD_OUTPUT="${AOE_STUB_ADD_OUTPUT:-}" \
    AOE_STUB_ADD_EXIT="${AOE_STUB_ADD_EXIT:-0}" \
    AOE_STUB_SESSION_START_EXIT="${AOE_STUB_SESSION_START_EXIT:-0}" \
    AOE_STUB_CAPTURE_OUTPUT="${AOE_STUB_CAPTURE_OUTPUT:-⬢ test-model}" \
    AOE_STUB_SEND_EXIT="${AOE_STUB_SEND_EXIT:-0}" \
    sh "$AOE_CMD" "$@"
}

canonical_add_output='✓ Added session: audit-20260101-000000
  Profile: main
  Path:    /tmp/proj
  ID:      24777d8e72f2416c
'

echo "== usage =="
out="$(run_aoe_cmd -d /tmp/proj -n audit 2>&1)" && status=0 || status=$?
check "missing message exits non-zero" "$status" 1
if printf '%s' "$out" | grep -qi usage; then ok "missing message prints usage"; else bad "missing message prints usage"; fi

echo "== OMP dispatch =="
AOE_STUB_ADD_OUTPUT="$canonical_add_output" run_aoe_cmd -d /tmp/proj -n audit /audit >/dev/null 2>&1 && status=0 || status=$?
check "dispatch exits zero" "$status" 0
add_line="$(grep '^add' "$AOE_LOG")"
case "$add_line" in
  *$'add\t/tmp/proj\t--title\taudit-'*'--tool	omp'*) ok "adds an OMP session" ;;
  *) bad "adds an OMP session (got: $add_line)" ;;
esac
check "sends the original message" "$(grep '^send' "$AOE_LOG")" $'send\t24777d8e72f2416c\t/audit'

echo "== worktree and scratch =="
AOE_STUB_ADD_OUTPUT="$canonical_add_output" run_aoe_cmd -d /tmp/proj -n audit -w fix/audit -b /audit >/dev/null 2>&1 && status=0 || status=$?
check "worktree dispatch exits zero" "$status" 0
add_line="$(grep '^add' "$AOE_LOG")"
case "$add_line" in
  *$'--worktree\tfix/audit\t--new-branch'*) ok "passes worktree flags" ;;
  *) bad "passes worktree flags (got: $add_line)" ;;
esac
AOE_STUB_ADD_OUTPUT="$canonical_add_output" run_aoe_cmd -s -n kb-enrich /kb-enrich >/dev/null 2>&1 && status=0 || status=$?
check "scratch dispatch exits zero" "$status" 0
case "$(grep '^add' "$AOE_LOG")" in
  *$'add\t--scratch\t--title\tkb-enrich-'*'--tool	omp'*) ok "adds an OMP scratch session" ;;
  *) bad "adds an OMP scratch session" ;;
esac

echo "== plan skip =="
AOE_STUB_ADD_OUTPUT="$canonical_add_output" run_aoe_cmd -d /tmp/proj -n audit -P -t omp /audit >/dev/null 2>&1 && status=0 || status=$?
check "explicit OMP plan-skip dispatch exits zero" "$status" 0
case "$(grep '^add' "$AOE_LOG")" in
  *$'--tool	omp	--extra-args	--config '"$TEST_HOME"$'/.omp/agent/no-plan.yml --model test-model'*) ok "uses no-plan overlay and default model role" ;;
  *) bad "uses no-plan overlay and default model role (got: $(grep '^add' "$AOE_LOG"))" ;;
esac
out="$(run_aoe_cmd -d /tmp/proj -n audit -t cursor /audit 2>&1)" && status=0 || status=$?
check "non-OMP tool exits non-zero" "$status" 1

echo "== failures =="
AOE_STUB_ADD_EXIT=1 run_aoe_cmd -d /tmp/proj -n audit /audit >/dev/null 2>&1 && status=0 || status=$?
check "add failure exits non-zero" "$status" 1
AOE_STUB_ADD_OUTPUT="$canonical_add_output" AOE_STUB_SESSION_START_EXIT=1 run_aoe_cmd -d /tmp/proj -n audit /audit >/dev/null 2>&1 && status=0 || status=$?
check "start failure exits non-zero" "$status" 1
AOE_STUB_ADD_OUTPUT="$canonical_add_output" AOE_STUB_CAPTURE_OUTPUT="booting" AOE_CMD_READY_TIMEOUT=1 AOE_CMD_POLL_INTERVAL=0 run_aoe_cmd -d /tmp/proj -n audit /audit >/dev/null 2>&1 && status=0 || status=$?
check "readiness timeout exits non-zero" "$status" 1
AOE_STUB_ADD_OUTPUT="$canonical_add_output" AOE_STUB_SEND_EXIT=1 run_aoe_cmd -d /tmp/proj -n audit /audit >/dev/null 2>&1 && status=0 || status=$?
check "send failure exits non-zero" "$status" 1

echo
echo "== summary: $pass passed, $fail failed =="
[ "$fail" -eq 0 ]
