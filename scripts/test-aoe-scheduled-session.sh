#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aoe-scheduled-session-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

FAKE_AOE="$WORK/aoe"
LOG="$WORK/aoe.log"
cat >"$FAKE_AOE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'CALL\n'
  for arg in "$@"; do
    printf 'ARG=%s\n' "$arg"
  done
} >>"$AOE_TEST_LOG"

case "$1" in
  add)
    session_path="$AOE_TEST_ROOT/scratch/testsession"
    mkdir -p "$session_path"
    printf '  ID: testsession\n  Path: %s\n' "$session_path"
    ;;
  session|send)
    ;;
  *)
    exit 64
    ;;
esac
EOF
chmod +x "$FAKE_AOE"

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check() { local label=$1; shift; if "$@"; then ok "$label"; else bad "$label"; fi; }

run_wrapper() {
  AOE_BIN="$FAKE_AOE" \
    AOE_STARTUP_DELAY_SECONDS=0 \
    AOE_TEST_LOG="$LOG" \
    AOE_TEST_ROOT="$WORK" \
    XDG_STATE_HOME="$WORK/state" \
    "$REPO_ROOT/dot_local/bin/executable_aoe-scheduled-session" "$@"
}

mkdir -p "$WORK/project"
: >"$LOG"
check "runs a project session without optional OMP arguments" run_wrapper fix-prod-errors /fix-prod-errors "$WORK/project"
if grep -Fqx 'ARG=--extra-args' "$LOG"; then
  bad "omits empty OMP extra arguments"
else
  ok "omits empty OMP extra arguments"
fi

printf '{"mcpServers":{"collector":{}}}\n' >"$WORK/kb-mcp.json"
: >"$LOG"
if AOE_OMP_MODEL=@default AOE_OMP_PROJECT_MCP_CONFIG="$WORK/kb-mcp.json" run_wrapper kb-enrich /kb-enrich; then
  ok "runs a scratch KB session"
else
  bad "runs a scratch KB session"
fi
check "copies the KB MCP overlay" cmp "$WORK/kb-mcp.json" "$WORK/scratch/testsession/.omp/mcp.json"
if grep -Fqx 'ARG=--extra-args' "$LOG" && grep -Fqx 'ARG=--model @default' "$LOG"; then
  ok "passes the pinned KB model"
else
  bad "passes the pinned KB model"
fi
if [[ "$(stat -f '%Lp' "$WORK/scratch/testsession/.omp/mcp.json")" == 600 ]]; then
  ok "makes the KB MCP overlay private"
else
  bad "makes the KB MCP overlay private"
fi

if AOE_OMP_PROJECT_MCP_CONFIG="$WORK/kb-mcp.json" run_wrapper invalid /invalid "$WORK/project" >/dev/null 2>&1; then
  bad "rejects a project MCP overlay outside scratch sessions"
else
  ok "rejects a project MCP overlay outside scratch sessions"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
