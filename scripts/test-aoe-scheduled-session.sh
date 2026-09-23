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
    if [[ "${AOE_INVALID_ID:-false}" == true ]]; then
      printf '  ID: invalid id\n'
      exit 0
    fi
    session_path="$AOE_TEST_ROOT/scratch/testsession"
    mkdir -p "$session_path"
    printf '  ID: testsession\n  Path: %s\n' "$session_path"
    ;;
  session)
    if [[ "${AOE_START_ERROR_BUT_LIVE:-false}" == true ]]; then
      printf 'session start reported a lost lifecycle reservation\n' >&2
      exit 1
    fi
    ;;
  ps)
    if [[ "${AOE_START_ERROR_BUT_LIVE:-false}" == true ]]; then
      ps_count_file="$AOE_TEST_ROOT/ps-count"
      ps_count=0
      if [[ -f "$ps_count_file" ]]; then
        ps_count=$(<"$ps_count_file")
      fi
      ps_count=$((ps_count + 1))
      printf '%s\n' "$ps_count" >"$ps_count_file"
      if [[ "$ps_count" -ge 2 ]]; then
        printf '[{"session":"testsession","pid":1234}]\n'
      else
        printf '[]\n'
      fi
    else
      printf '[]\n'
    fi
    ;;
  send)
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
  local title=$1 prompt=$2 prompt_file="$WORK/prompt.md"
  printf '%s' "$prompt" > "$prompt_file"
  shift 2
  AOE_BIN="$FAKE_AOE" \
    JQ_BIN="${JQ_BIN:-/opt/homebrew/bin/jq}" \
    AOE_STARTUP_DELAY_SECONDS=0 \
    AOE_TEST_LOG="$LOG" \
    AOE_TEST_ROOT="$WORK" \
    XDG_STATE_HOME="$WORK/state" \
    AOE_SESSION_GROUP="${AOE_SESSION_GROUP:-Scheduled}" \
    AOE_WORKTREE_BRANCH="${AOE_WORKTREE_BRANCH:-}" \
    AOE_NEW_BRANCH="${AOE_NEW_BRANCH:-false}" \
    "$REPO_ROOT/dot_local/bin/executable_aoe-scheduled-session" "$title" "$prompt_file" "$@"
}

mkdir -p "$WORK/project"
: >"$LOG"
check "runs a project session without optional OMP arguments" run_wrapper fix-prod-errors "triage production errors"
if grep -Fqx 'ARG=--extra-args' "$LOG"; then
  bad "omits empty OMP extra arguments"
else
  ok "omits empty OMP extra arguments"
fi
git -C "$WORK/project" init -q
: >"$LOG"
if AOE_SESSION_GROUP=Attention AOE_WORKTREE_BRANCH=attention/test AOE_NEW_BRANCH=true run_wrapper attention /attention "$WORK/project"; then
  ok "runs an attention worktree session"
else
  bad "runs an attention worktree session"
fi
if grep -Fqx 'ARG=--worktree' "$LOG" &&
  grep -Fqx 'ARG=attention/test' "$LOG" &&
  grep -Fqx 'ARG=--new-branch' "$LOG" &&
  grep -Fqx 'ARG=--group' "$LOG" &&
  grep -Fqx 'ARG=Attention' "$LOG"; then
  ok "passes attention group and worktree options"
else
  bad "passes attention group and worktree options"
fi
: >"$LOG"
: >"$WORK/liveness.err"
if AOE_START_ERROR_BUT_LIVE=true run_wrapper lifecycle-race /lifecycle-race 2>"$WORK/liveness.err"; then
  ok "accepts a live session when start reports a lost reservation"
else
  bad "accepts a live session when start reports a lost reservation"
fi
if [[ "$(grep -Fc 'ARG=session' "$LOG" || true)" == 1 ]] &&
  grep -Fqx 'ARG=ps' "$LOG" &&
  grep -Fqx 'ARG=send' "$LOG" &&
  [[ ! -s "$WORK/liveness.err" ]]; then
  ok "does not retry or surface a false startup error"
else
  bad "does not retry or surface a false startup error"
fi

printf '{"mcpServers":{"collector":{}}}\n' >"$WORK/kb-mcp.json"
daily_prompt=$(cat "$REPO_ROOT/dot_agents/prompts/daily-maintenance.md")
: >"$LOG"
correlation_id=E4D58213-F415-4A54-B9F9-F7993B6C0CDF
if AOE_CORRELATION="$correlation_id" AOE_OMP_MODEL=@default AOE_OMP_PROJECT_MCP_CONFIG="$WORK/kb-mcp.json" run_wrapper daily-maintenance "$daily_prompt"; then
  ok "runs a scratch KB session"
else
  bad "runs a scratch KB session"
fi
check "copies the KB MCP overlay" cmp "$WORK/kb-mcp.json" "$WORK/scratch/testsession/.omp/mcp.json"
if grep -Fqx 'ARG=--extra-args' "$LOG" && grep -Fqx 'ARG=--model @default' "$LOG" && ! grep -Fq -- '--prewalk-into' "$LOG"; then
  ok "passes the pinned OMP model without prewalk"
else
  bad "passes the pinned OMP model without prewalk"
fi
if grep -Fqx "ARG=daily-maintenance-E4D58213" "$LOG" &&
  grep -Fqx 'ARG=Run both daily maintenance workflows in this session.' "$LOG" &&
  grep -Fq 'error.grouping_key' "$LOG" &&
  grep -Fq 'kb journal append|list|show' "$LOG" &&
  grep -Fq "AOE_CORRELATION=$correlation_id" "$LOG" &&
  grep -Fq "\"correlationId\":\"$correlation_id\"" "$WORK/state/aoe/omp-session-map/testsession.json"; then
  ok "preserves the caller correlation in session state and prompt"
else
  bad "preserves the caller correlation in session state and prompt"
fi
if [[ "$(stat -f '%Lp' "$WORK/scratch/testsession/.omp/mcp.json")" == 600 ]]; then
  ok "makes the KB MCP overlay private"
else
  bad "makes the KB MCP overlay private"
fi

if AOE_INVALID_ID=true run_wrapper invalid /invalid >/dev/null 2>&1; then
  bad "rejects an invalid session ID before starting"
else
  ok "rejects an invalid session ID before starting"
fi

if AOE_OMP_PROJECT_MCP_CONFIG="$WORK/kb-mcp.json" run_wrapper invalid /invalid "$WORK/project" >/dev/null 2>&1; then
  bad "rejects a project MCP overlay outside scratch sessions"
else
  ok "rejects a project MCP overlay outside scratch sessions"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
