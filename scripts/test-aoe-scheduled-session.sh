#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aoe-scheduled-session-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

FAKE_AOE="$WORK/aoe"
LOG="$WORK/aoe.log"
START_LOG="$WORK/start.log"
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
    if [[ -f "$AOE_TEST_ROOT/scratch/testsession/.omp/mcp.json" ]]; then
      printf 'overlay=present\n' >>"$AOE_TEST_START_LOG"
    else
      printf 'overlay=absent\n' >>"$AOE_TEST_START_LOG"
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
    AOE_TEST_LOG="$LOG" \
    AOE_TEST_START_LOG="$START_LOG" \
    AOE_TEST_ROOT="$WORK" \
    AOE_SESSION_GROUP="${AOE_SESSION_GROUP:-Scheduled}" \
    AOE_WORKTREE_BRANCH="${AOE_WORKTREE_BRANCH:-}" \
    AOE_NEW_BRANCH="${AOE_NEW_BRANCH:-false}" \
    "$REPO_ROOT/dot_local/bin/executable_aoe-scheduled-session" "$title" "$prompt_file" "$@"
}

mkdir -p "$WORK/project"
: >"$LOG"
: >"$START_LOG"
check "runs a project session without optional OMP arguments" run_wrapper fix-prod-errors "triage production errors"
if grep -Fqx 'ARG=--tool' "$LOG" && grep -Fqx 'ARG=omp' "$LOG"; then
  ok "defaults to the omp agent"
else
  bad "defaults to the omp agent"
fi
if grep -Fqx 'ARG=--scratch' "$LOG"; then
  ok "uses a scratch directory without a project path"
else
  bad "uses a scratch directory without a project path"
fi
if grep -Fqx 'ARG=--extra-args' "$LOG"; then
  bad "omits empty OMP extra arguments"
else
  ok "omits empty OMP extra arguments"
fi
if grep -Fqx 'ARG=session' "$LOG" && grep -Fqx 'ARG=start' "$LOG" && grep -Fqx 'ARG=send' "$LOG"; then
  ok "creates, starts and prompts the session"
else
  bad "creates, starts and prompts the session"
fi
if [[ "$(grep -Fc 'ARG=start' "$LOG" || true)" == 1 ]] && [[ "$(grep -Fc 'ARG=send' "$LOG" || true)" == 1 ]]; then
  ok "starts and sends exactly once"
else
  bad "starts and sends exactly once"
fi
if grep -Fqx 'ARG=triage production errors' "$LOG"; then
  ok "sends the prompt file contents"
else
  bad "sends the prompt file contents"
fi
if grep -Eq 'ARG=fix-prod-errors-[0-9A-Fa-f]{8}$' "$LOG"; then
  ok "suffixes the session title uniquely"
else
  bad "suffixes the session title uniquely"
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
  grep -Fqx 'ARG=Attention' "$LOG" &&
  grep -Fqx "ARG=$WORK/project" "$LOG"; then
  ok "passes the project path, group and worktree options"
else
  bad "passes the project path, group and worktree options"
fi

: >"$LOG"
if AOE_TOOL=freebuff AOE_OMP_MODEL=@default run_wrapper personal /personal "$WORK/project"; then
  ok "runs a project session with a configured agent"
else
  bad "runs a project session with a configured agent"
fi
if grep -Fqx 'ARG=--tool' "$LOG" && grep -Fqx 'ARG=freebuff' "$LOG" && ! grep -Fqx 'ARG=--extra-args' "$LOG"; then
  ok "uses the configured agent without OMP-only arguments"
else
  bad "uses the configured agent without OMP-only arguments"
fi

if AOE_TOOL='omp --title injected' run_wrapper invalid-agent /invalid >/dev/null 2>&1; then
  bad "rejects an unsupported agent name"
else
  ok "rejects an unsupported agent name"
fi

printf '{"mcpServers":{"collector":{}}}\n' >"$WORK/kb-mcp.json"
daily_prompt=$(cat "$REPO_ROOT/dot_agents/prompts/daily-maintenance.md")
: >"$LOG"
: >"$START_LOG"
if AOE_OMP_MODEL=@default AOE_OMP_PROJECT_MCP_CONFIG="$WORK/kb-mcp.json" run_wrapper daily-maintenance "$daily_prompt"; then
  ok "runs a scratch KB session"
else
  bad "runs a scratch KB session"
fi
check "copies the KB MCP overlay" cmp "$WORK/kb-mcp.json" "$WORK/scratch/testsession/.omp/mcp.json"
if grep -Fqx 'overlay=present' "$START_LOG"; then
  ok "installs the overlay before starting the agent"
else
  bad "installs the overlay before starting the agent"
fi
if [[ "$(stat -f '%Lp' "$WORK/scratch/testsession/.omp/mcp.json")" == 600 ]]; then
  ok "makes the KB MCP overlay private"
else
  bad "makes the KB MCP overlay private"
fi
if grep -Fqx 'ARG=--scratch' "$LOG" && grep -Fqx 'ARG=--extra-args' "$LOG" && grep -Fqx 'ARG=--model @default' "$LOG"; then
  ok "passes the pinned OMP model as one extra argument"
else
  bad "passes the pinned OMP model as one extra argument"
fi
if grep -Fq 'AOE_CORRELATION' "$LOG"; then
  bad "keeps the prompt free of retired correlation tokens"
else
  ok "keeps the prompt free of retired correlation tokens"
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
