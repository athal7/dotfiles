#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/attention-session-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

REPO="$WORK/repo"
mkdir -p "$REPO"
FAKE_GH="$WORK/gh"
FAKE_GIT="$WORK/git"
DISPATCHER="$WORK/dispatcher"
GH_LOG="$WORK/gh.log"
GIT_LOG="$WORK/git.log"
DISPATCH_LOG="$WORK/dispatch.log"
BRANCH_STATE="$WORK/branch-state"
: >"$GH_LOG"
: >"$GIT_LOG"
: >"$DISPATCH_LOG"
: >"$BRANCH_STATE"

cat >"$FAKE_GH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$1" "$2" >>"$ATTENTION_GH_LOG"
if [[ "$ATTENTION_MODE" == pr && "$1" == pr && "$2" == view ]]; then
  printf '63\tfeature/fork\thead-owner\thead-repo\n'
elif [[ "$ATTENTION_MODE" == issue && "$1" == issue && "$2" == view ]]; then
  printf '64\n'
else
  exit 1
fi
EOF

cat >"$FAKE_GIT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command=$1
if [[ "$command" == -C ]]; then
  shift 2
  command=$1
fi
shift
printf 'command=%s args=%s\n' "$command" "$*" >>"$ATTENTION_GIT_LOG"
case "$command" in
  rev-parse)
    case "${1:-}" in
      --show-toplevel) printf '%s\n' "$ATTENTION_REPO" ;;
      refs/remotes/*|refs/heads/*) printf '%s\n' "$ATTENTION_HEAD_SHA" ;;
      *) exit 1 ;;
    esac
    ;;
  check-ref-format)
    exit 0
    ;;
  fetch)
    ;;
  show-ref)
    [[ -s "$ATTENTION_BRANCH_STATE" ]]
    ;;
  branch)
    printf '%s\n' "$ATTENTION_HEAD_SHA" >"$ATTENTION_BRANCH_STATE"
    ;;
  *)
    exit 64
    ;;
esac
EOF

cat >"$DISPATCHER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'group=%s branch=%s new=%s argc=%s\n' "${AOE_SESSION_GROUP:-}" "${AOE_WORKTREE_BRANCH:-}" "${AOE_NEW_BRANCH:-}" "$#"
  for arg in "$@"; do
    printf 'arg=%s\n' "$arg"
  done
  printf 'prompt=%s\n' "$(cat "$2")"
  printf 'prompt_mode=%s\n' "$(stat -f '%Lp' "$2")"
} >>"$ATTENTION_DISPATCH_LOG"
EOF
chmod +x "$FAKE_GH" "$FAKE_GIT" "$DISPATCHER"

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check() { local label=$1; shift; if "$@"; then ok "$label"; else bad "$label"; fi; }

run_attention() {
  ATTENTION_GH_LOG="$GH_LOG" \
    ATTENTION_GIT_LOG="$GIT_LOG" \
    ATTENTION_DISPATCH_LOG="$DISPATCH_LOG" \
    ATTENTION_BRANCH_STATE="$BRANCH_STATE" \
    ATTENTION_REPO="$REPO" \
    ATTENTION_HEAD_SHA=deadbeef \
    AOE_SESSION_DISPATCHER="$DISPATCHER" \
    GH_BIN="$FAKE_GH" \
    GIT_BIN="$FAKE_GIT" \
    ATTENTION_MODE="${ATTENTION_MODE:-}" \
    "$REPO_ROOT/dot_local/bin/executable_attention-session" "$@"
}

run_attention scratch calendar-title calendar-prompt
prompt_path=$(sed -n '3s/^arg=//p' "$DISPATCH_LOG")
if grep -Fqx 'group=Attention branch= new= argc=2' "$DISPATCH_LOG" &&
  grep -Fqx 'arg=calendar-title' "$DISPATCH_LOG" &&
  grep -Fqx 'prompt=calendar-prompt' "$DISPATCH_LOG" &&
  grep -Fqx 'prompt_mode=600' "$DISPATCH_LOG" &&
  [[ -n "$prompt_path" && ! -e "$prompt_path" ]]; then
  ok "dispatches scratch attention sessions without a TTY"
else
  bad "dispatches scratch attention sessions without a TTY"
fi

: >"$DISPATCH_LOG"
: >"$GIT_LOG"
export ATTENTION_MODE=pr
run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt extra-content
run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt extra-content
unset ATTENTION_MODE
if grep -Fqx 'group=Attention branch=attention/pr-63 new=false argc=3' "$DISPATCH_LOG" &&
  grep -Fqx 'arg=pr-title' "$DISPATCH_LOG" &&
  grep -Fq 'Additional session content:' "$DISPATCH_LOG" &&
  grep -Fq 'https://github.com/head-owner/head-repo.git' "$GIT_LOG" &&
  grep -Fq '+refs/heads/feature/fork:refs/remotes/origin/attention-pr-63' "$GIT_LOG"; then
  ok "dispatches PR work from its authoritative head repository"
else
  bad "dispatches PR work from its authoritative head repository"
  printf 'PR dispatch log:\n%s\nPR git log:\n%s\n' "$(cat "$DISPATCH_LOG")" "$(cat "$GIT_LOG")" >&2
fi
if [[ "$(grep -c '^command=branch' "$GIT_LOG")" == 1 ]]; then
  ok "reuses a matching PR branch on repeat dispatch"
else
  bad "reuses a matching PR branch on repeat dispatch"
fi
: >"$DISPATCH_LOG"
: >"$GIT_LOG"
: >"$BRANCH_STATE"
export ATTENTION_MODE=issue
run_attention github "$REPO" 64 issue/64 issue-title issue-prompt ''
unset ATTENTION_MODE
if grep -Fqx 'group=Attention branch=issue/64 new=true argc=3' "$DISPATCH_LOG" &&
  grep -Fqx 'arg=issue-title' "$DISPATCH_LOG" &&
  grep -Fq 'issue view' "$GH_LOG"; then
  ok "creates a new worktree branch for issues"
else
  bad "creates a new worktree branch for issues"
  printf 'Issue dispatch log:\n%s\nGitHub log:\n%s\n' "$(cat "$DISPATCH_LOG")" "$(cat "$GH_LOG")" >&2
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
