#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/attention-session-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

REPO="$WORK/repo"
REGISTERED_REPO="$WORK/nested/remote-repo"
mkdir -p "$REPO" "$REGISTERED_REPO"
FAKE_GH="$WORK/gh"
FAKE_GIT="$WORK/git"
FAKE_AOE="$WORK/aoe"
DISPATCHER="$WORK/dispatcher"
GH_LOG="$WORK/gh.log"
GIT_LOG="$WORK/git.log"
DISPATCH_LOG="$WORK/dispatch.log"
BRANCH_STATE="$WORK/branch-state"
SESSIONS="$WORK/sessions.json"
AOE_LOG="$WORK/aoe.log"
: >"$GH_LOG"
: >"$GIT_LOG"
: >"$DISPATCH_LOG"
: >"$BRANCH_STATE"
printf '[]\n' >"$SESSIONS"
: >"$AOE_LOG"

cat >"$FAKE_GH" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$1" "$2" >>"$ATTENTION_GH_LOG"
if [[ -n "${ATTENTION_EXPECTED_REPO:-}" ]]; then
  case " $* " in
    *" --repo $ATTENTION_EXPECTED_REPO "*) ;;
    *) exit 1 ;;
  esac
fi
if [[ "$ATTENTION_MODE" == pr && "$1" == pr && "$2" == view ]]; then
  if [[ "$3" == 65 ]]; then
    printf '65\tfeature/fork\tother-owner\tother-repo\n'
  else
    printf '63\tfeature/fork\thead-owner\thead-repo\n'
  fi
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
repo=$ATTENTION_REPO
if [[ "$command" == -C ]]; then
  repo=$2
  shift 2
  command=$1
fi
shift
printf 'command=%s args=%s\n' "$command" "$*" >>"$ATTENTION_GIT_LOG"
case "$command" in
  rev-parse)
    case "${1:-}" in
      --show-toplevel) printf '%s\n' "$repo" ;;
      --path-format=absolute)
        case "$repo" in */wrong-repo) printf '%s/.git\n' "$repo" ;; *) printf '%s/.git\n' "$ATTENTION_REPO" ;; esac ;;
      refs/remotes/*|refs/heads/*) printf '%s\n' "$ATTENTION_HEAD_SHA" ;;
      *) exit 1 ;;
    esac
    ;;
  symbolic-ref)
    case "$repo" in
      */pr-session|*/wrong-repo|*/one|*/two) printf '%s\n' feature/fork ;;
      */issue-session) printf '%s\n' issue/64 ;;
      *) printf '%s\n' other-branch ;;
    esac
    ;;
  remote)
    case "$*" in
      "get-url origin") printf '%s\n' "${ATTENTION_HEAD_ORIGIN:-https://github.com/head-owner/head-repo.git}" ;;
      -v)
        [[ "$repo" == "$ATTENTION_REGISTERED_REPO" || "$repo" == "$ATTENTION_REPO" ]] || exit 1
        printf 'origin\t%s (fetch)\n' "${ATTENTION_ORIGIN:-git@github.com:example/remote-repo.git}" ;;
      *) exit 1 ;;
    esac
    ;;
  check-ref-format)
    exit 0
    ;;
  fetch)
    ;;
  worktree)
    [[ "$*" == "list --porcelain -z" ]] || exit 1
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
  printf 'tool=%s\n' "${AOE_TOOL:-}"
  for arg in "$@"; do
    printf 'arg=%s\n' "$arg"
  done
  printf 'prompt=%s\n' "$(cat "$2")"
  printf 'prompt_mode=%s\n' "$(stat -f '%Lp' "$2")"
} >>"$ATTENTION_DISPATCH_LOG"
EOF
cat >"$FAKE_AOE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "$*" >>"$ATTENTION_AOE_LOG"
case "$*" in
  'project list --json') echo "[{\"path\":\"$ATTENTION_REGISTERED_REPO\"}]" ;;
  'list --all --json') cat "$ATTENTION_SESSIONS" ;;
  '-p main session show '*)
    [[ "${ATTENTION_SHOW_FAIL:-}" != 1 ]] || exit 1
    printf '{"status":"%s"}\n' "${ATTENTION_SESSION_STATUS:-running}" ;;
  '-p main ps --json '*) printf '{"substrate":"%s"}\n' "${ATTENTION_SUBSTRATE:-tmux}" ;;
  '-p main session start '*|'-p main session unarchive '*|'-p main session unsnooze '*) : ;;
  'list --json') cat "$ATTENTION_SESSIONS" ;;
  send\ *) echo "message=$3" >>"$ATTENTION_AOE_LOG"; [[ "${ATTENTION_SEND_FAIL:-}" != 1 ]] ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$FAKE_GH" "$FAKE_GIT" "$FAKE_AOE" "$DISPATCHER"

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
    ATTENTION_REGISTERED_REPO="$REGISTERED_REPO" \
    ATTENTION_HEAD_SHA=deadbeef \
    ATTENTION_SESSIONS="$SESSIONS" \
    ATTENTION_AOE_LOG="$AOE_LOG" \
    AOE_SESSION_DISPATCHER="$DISPATCHER" \
    AOE_BIN="$FAKE_AOE" \
    GH_BIN="$FAKE_GH" \
    GIT_BIN="${ATTENTION_GIT_BIN:-$FAKE_GIT}" \
    ATTENTION_MODE="${ATTENTION_MODE:-}" \
    "$REPO_ROOT/dot_local/bin/executable_attention-session" "$@"
}

mkdir -p "$WORK/scratch/scratch-id" "$WORK/scratch/first" "$WORK/scratch/second" \
  "$WORK/trees/pr-session" "$WORK/trees/wrong-repo" "$WORK/trees/wrong-branch" "$WORK/trees/one" "$WORK/trees/two" "$WORK/trees/issue-session"
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

cat >"$SESSIONS" <<EOF
[{"id":"scratch-id","title":"calendar-title-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/scratch/scratch-id","worktree":null}]
EOF
: >"$DISPATCH_LOG"
: >"$AOE_LOG"
run_attention scratch calendar-title 'continue calendar work'
if [[ ! -s "$DISPATCH_LOG" ]] && grep -Fqx -- '-p main session show scratch-id --json' "$AOE_LOG" &&
  ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "surfaces the existing scratch session without injecting text"
else
  bad "surfaces the existing scratch session without injecting text"
fi
: >"$DISPATCH_LOG"
export ATTENTION_SHOW_FAIL=1
if run_attention scratch calendar-title 'retry after failure' >"$WORK/send-error.out" 2>&1; then
  bad "does not create a duplicate when session inspection fails"
elif [[ ! -s "$DISPATCH_LOG" ]] && grep -Fq 'cannot inspect AoE session scratch-id' "$WORK/send-error.out"; then
  ok "does not create a duplicate when session inspection fails"
else
  bad "does not create a duplicate when session inspection fails"
fi
unset ATTENTION_SHOW_FAIL
cat >"$SESSIONS" <<EOF
[
 {"id":"archived","title":"calendar-title-1234abcd","group":"Attention","tool":"omp","state":"archived","path":"$WORK/scratch/archived","worktree":null},
 {"id":"trashed","title":"calendar-title-1234abcd","group":"Attention","tool":"omp","state":"trashed","path":"$WORK/scratch/trashed","worktree":null},
 {"id":"snoozed","title":"calendar-title-1234abcd","group":"Attention","tool":"omp","state":"snoozed","path":"$WORK/scratch/snoozed","worktree":null},
 {"id":"other-group","title":"calendar-title-1234abcd","group":"Scheduled","tool":"omp","state":"live","path":"$WORK/scratch/other-group","worktree":null},
 {"id":"other-tool","title":"calendar-title-1234abcd","group":"Attention","tool":"claude","state":"live","path":"$WORK/scratch/other-tool","worktree":null},
 {"id":"other-title","title":"calendar-title-more-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/scratch/other-title","worktree":null},
 {"id":"project-path","title":"calendar-title-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/projects/project-path","worktree":null}
]
EOF
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
run_attention scratch calendar-title 'fresh request'
if grep -Fqx 'prompt=fresh request' "$DISPATCH_LOG" && ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "ignores retired, snoozed, and unrelated scratch sessions"
else
  bad "ignores retired, snoozed, and unrelated scratch sessions"
fi
cat >"$SESSIONS" <<EOF
[
 {"id":"first","title":"calendar-title-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/scratch/first","worktree":null},
 {"id":"second","title":"calendar-title-5678abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/scratch/second","worktree":null}
]
EOF
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
if run_attention scratch calendar-title 'ambiguous request' >"$WORK/ambiguous.out" 2>&1; then
  bad "rejects ambiguous scratch sessions without sending or creating"
elif [[ ! -s "$DISPATCH_LOG" ]] && ! grep -Fq 'send ' "$AOE_LOG" &&
  grep -Fq 'multiple sessions match this Attention item' "$WORK/ambiguous.out"; then
  ok "rejects ambiguous scratch sessions without sending or creating"
else
  bad "rejects ambiguous scratch sessions without sending or creating"
fi
: >"$SESSIONS"
: >"$DISPATCH_LOG"
: >"$AOE_LOG"
if run_attention scratch calendar-title 'unknown list' >"$WORK/list-error.out" 2>&1; then
  bad "does not create a session when AoE returns an empty listing"
elif [[ ! -s "$DISPATCH_LOG" ]] && ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "does not create a session when AoE returns an empty listing"
else
  bad "does not create a session when AoE returns an empty listing"
fi
echo '[]' >"$SESSIONS"
: >"$DISPATCH_LOG"
: >"$GIT_LOG"
export ATTENTION_MODE=pr
run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt extra-content example/remote-repo
run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt extra-content example/remote-repo
unset ATTENTION_MODE
if grep -Fqx 'group=Attention branch=feature/fork new=false argc=3' "$DISPATCH_LOG" &&
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
cat >"$SESSIONS" <<EOF
[
 {"id":"wrong-repo","title":"pr-title-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/trees/wrong-repo","worktree":{"branch":"attention/pr-63","main_repo_path":"$WORK/other-repo"}},
 {"id":"wrong-branch","title":"pr-title-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/trees/wrong-branch","worktree":{"branch":"feature/fork","main_repo_path":"$REPO"}},
 {"id":"same-title-scratch","title":"pr-title-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/scratch/same-title-scratch","worktree":null},
 {"id":"pr-session","title":"renamed-by-user","group":"Attention","tool":"omp","state":"live","path":"$WORK/trees/pr-session","worktree":{"branch":"attention/pr-63","main_repo_path":"$REPO/"}}
]
EOF
: >"$DISPATCH_LOG"
: >"$GH_LOG"
: >"$GIT_LOG"
: >"$AOE_LOG"
export ATTENTION_MODE=pr
run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt extra-content example/remote-repo
unset ATTENTION_MODE
if [[ ! -s "$DISPATCH_LOG" ]] &&
  ! grep -Eq 'command=(fetch|branch|show-ref)' "$GIT_LOG" &&
  grep -Fqx -- '-p main session show pr-session --json' "$AOE_LOG" &&
  ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "resumes the matching PR without refetching or creating a worktree"
else
  bad "resumes the matching PR without refetching or creating a worktree"
fi
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
export ATTENTION_HEAD_ORIGIN=https://github.com/other-owner/head-repo.git ATTENTION_MODE=pr
if run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo >"$WORK/head-origin.out" 2>&1; then
  bad "rejects a matching branch from another PR head repository"
elif [[ ! -s "$DISPATCH_LOG" ]] && ! grep -Fq 'session start' "$AOE_LOG" &&
  grep -Fq 'does not match PR head repository' "$WORK/head-origin.out"; then
  ok "rejects a matching branch from another PR head repository"
else
  bad "rejects a matching branch from another PR head repository"
fi
unset ATTENTION_HEAD_ORIGIN ATTENTION_MODE
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
export ATTENTION_SESSION_STATUS=stopped ATTENTION_MODE=pr
run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo
unset ATTENTION_SESSION_STATUS ATTENTION_MODE
if [[ ! -s "$DISPATCH_LOG" ]] && grep -Fqx -- '-p main session start pr-session' "$AOE_LOG" &&
  ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "starts the stopped matching session without injecting text"
else
  bad "starts the stopped matching session without injecting text"
fi
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
export ATTENTION_SESSION_STATUS=stopped ATTENTION_SUBSTRATE=acp ATTENTION_MODE=pr
if run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo >"$WORK/structured.out" 2>&1; then
  bad "does not start an ACP session as a tmux session"
elif [[ ! -s "$DISPATCH_LOG" ]] && ! grep -Fq 'session start' "$AOE_LOG"; then
  ok "does not start an ACP session as a tmux session"
else
  bad "does not start an ACP session as a tmux session"
fi
unset ATTENTION_SESSION_STATUS ATTENTION_SUBSTRATE ATTENTION_MODE
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
export ATTENTION_SESSION_STATUS=error ATTENTION_MODE=pr
if run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo >"$WORK/runtime-error.out" 2>&1; then
  bad "refuses to restart an errored session"
elif [[ ! -s "$DISPATCH_LOG" ]] && ! grep -Fq 'session start' "$AOE_LOG"; then
  ok "refuses to restart an errored session"
else
  bad "refuses to restart an errored session"
fi
unset ATTENTION_SESSION_STATUS ATTENTION_MODE
cat >"$SESSIONS" <<EOF
[{"id":"pr-session","title":"existing","profile":"main","state":"archived","snoozed_until":"2099-01-01T00:00:00Z","path":"$WORK/trees/pr-session","worktree":{"branch":"attention/pr-63","main_repo_path":"$REPO"}}]
EOF
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
ATTENTION_MODE="pr" run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo
if [[ ! -s "$DISPATCH_LOG" ]] &&
  grep -Fqx -- '-p main session unarchive pr-session' "$AOE_LOG" &&
  grep -Fqx -- '-p main session unsnooze pr-session' "$AOE_LOG" &&
  ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "wakes an archived and snoozed matching session"
else
  bad "wakes an archived and snoozed matching session"
fi
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
: >"$GH_LOG"
export ATTENTION_ORIGIN=git@github.com:example/another-repo.git
if run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo >"$WORK/origin.out" 2>&1; then
  bad "rejects an unrelated repository before sending"
elif [[ ! -s "$DISPATCH_LOG" && ! -s "$GH_LOG" ]] && ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "rejects an unrelated repository before sending"
else
  bad "rejects an unrelated repository before sending"
fi
unset ATTENTION_ORIGIN
cat >"$SESSIONS" <<EOF
[
 {"id":"pr-one","title":"pr-title-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/trees/one","worktree":{"branch":"attention/pr-63","main_repo_path":"$REPO"}},
 {"id":"pr-two","title":"pr-title-5678abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/trees/two","worktree":{"branch":"attention/pr-63","main_repo_path":"$REPO"}}
]
EOF
: >"$AOE_LOG"
: >"$DISPATCH_LOG"
if ATTENTION_MODE="pr" run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo >"$WORK/ambiguous-pr.out" 2>&1; then
  bad "rejects ambiguous PR worktrees"
elif [[ ! -s "$DISPATCH_LOG" ]] && ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "rejects ambiguous PR worktrees"
else
  bad "rejects ambiguous PR worktrees"
fi
echo '[]' >"$SESSIONS"
: >"$DISPATCH_LOG"
: >"$GIT_LOG"
: >"$BRANCH_STATE"
export ATTENTION_MODE=issue
run_attention github "$REPO" 64 issue/64 issue-title issue-prompt '' example/remote-repo
unset ATTENTION_MODE
if grep -Fqx 'group=Attention branch=issue/64 new=true argc=3' "$DISPATCH_LOG" &&
  grep -Fqx 'arg=issue-title' "$DISPATCH_LOG" &&
  grep -Fq 'issue view' "$GH_LOG"; then
  ok "creates a new worktree branch for issues"
else
  bad "creates a new worktree branch for issues"
  printf 'Issue dispatch log:\n%s\nGitHub log:\n%s\n' "$(cat "$DISPATCH_LOG")" "$(cat "$GH_LOG")" >&2
fi
cat >"$SESSIONS" <<EOF
[{"id":"issue-session","title":"issue-title-1234abcd","group":"Attention","tool":"omp","state":"live","path":"$WORK/trees/issue-session","worktree":{"branch":"issue/64","main_repo_path":"$REPO"}}]
EOF
: >"$DISPATCH_LOG"
: >"$GH_LOG"
: >"$GIT_LOG"
: >"$AOE_LOG"
ATTENTION_MODE=issue run_attention github "$REPO" 64 issue/64 issue-title 'continue issue' '' example/remote-repo
if [[ ! -s "$DISPATCH_LOG" ]] &&
  ! grep -Eq 'command=(fetch|branch|show-ref)' "$GIT_LOG" &&
  grep -Fqx -- '-p main session show issue-session --json' "$AOE_LOG" && ! grep -Fq 'send ' "$AOE_LOG"; then
  ok "resumes the existing issue worktree without creating another"
else
  bad "resumes the existing issue worktree without creating another"
fi
echo '[]' >"$SESSIONS"
export ATTENTION_MODE=pr
: >"$DISPATCH_LOG"
: >"$GIT_LOG"
: >"$BRANCH_STATE"
run_attention github "$WORK/0din-Loki" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo
if grep -Fqx "arg=$REGISTERED_REPO" "$DISPATCH_LOG" &&
  grep -Fqx 'group=Attention branch=feature/fork new=false argc=3' "$DISPATCH_LOG"; then
  ok "starts PR work from a registered checkout outside codeDir"
else
  bad "starts PR work from a registered checkout outside codeDir"
fi
: >"$DISPATCH_LOG"
if run_attention github "$WORK/0din-Loki" 63 attention/pr-63 pr-title base-prompt '' example/another-repo >"$WORK/missing.out" 2>&1; then
  bad "rejects an unregistered checkout instead of dispatching the wrong repository"
elif grep -Fq 'no registered AoE project matches example/another-repo' "$WORK/missing.out" && [[ ! -s "$DISPATCH_LOG" ]]; then
  ok "rejects an unregistered checkout instead of dispatching the wrong repository"
else
  bad "rejects an unregistered checkout instead of dispatching the wrong repository"
fi
unset ATTENTION_MODE

# Use real Git repositories to prove upstream PR branches contain the fetched head.
git init --quiet --initial-branch=feature/fork "$WORK/head"
git -C "$WORK/head" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false \
  commit --quiet --allow-empty -m 'Original title-slug branch'
stale_sha=$(git -C "$WORK/head" rev-parse HEAD)
git -C "$WORK/head" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false \
  commit --quiet --allow-empty -m 'Upstream PR head'
head_sha=$(git -C "$WORK/head" rev-parse HEAD)
for checkout in "$REPO" "$REGISTERED_REPO"; do
  git init --quiet --initial-branch=main "$checkout"
  git -C "$checkout" remote add origin https://github.com/head-owner/head-repo.git
  git -C "$checkout" remote add upstream https://github.com/example/remote-repo.git
  git -C "$checkout" config "url.$WORK/head.insteadOf" https://github.com/head-owner/head-repo.git
  git -C "$checkout" fetch --quiet --no-tags "$WORK/head" feature/fork
  git -C "$checkout" branch attention/upstream-pr "$stale_sha"
done
export ATTENTION_GIT_BIN
ATTENTION_GIT_BIN=$(command -v git)
export ATTENTION_EXPECTED_REPO=example/remote-repo
export ATTENTION_MODE=pr
: >"$DISPATCH_LOG"
if run_attention github "$REPO" 63 attention/upstream-pr upstream-pr upstream-prompt '' example/remote-repo &&
  [[ "$(git -C "$REPO" rev-parse refs/heads/feature/fork)" == "$head_sha" ]] &&
  [[ "$(git -C "$REPO" rev-parse refs/heads/attention/upstream-pr)" == "$stale_sha" ]] &&
  grep -Fqx 'group=Attention branch=feature/fork new=false argc=3' "$DISPATCH_LOG"; then
  ok "uses the actual PR head without changing a divergent title-slug branch"
else
  bad "uses the actual PR head without changing a divergent title-slug branch"
fi

: >"$DISPATCH_LOG"
if run_attention github "$WORK/missing-repo" 63 attention/upstream-pr upstream-pr upstream-prompt '' example/remote-repo &&
  [[ "$(git -C "$REGISTERED_REPO" rev-parse refs/heads/feature/fork)" == "$head_sha" ]] &&
  [[ "$(git -C "$REGISTERED_REPO" rev-parse refs/heads/attention/upstream-pr)" == "$stale_sha" ]]; then
  ok "finds a registered checkout by upstream when the suggested path is missing"
else
  bad "finds a registered checkout by upstream when the suggested path is missing"
fi
git -C "$REPO" config --unset "url.$WORK/head.insteadOf"
git -C "$REPO" worktree add -q "$WORK/existing worktree" feature/fork
git -C "$WORK/existing worktree" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false \
  commit -q --allow-empty -m 'Local work in progress'
local_sha=$(git -C "$WORK/existing worktree" rev-parse HEAD)
printf 'unfinished\n' > "$WORK/existing worktree/untracked"
: >"$DISPATCH_LOG"
if run_attention github "$REPO" 63 attention/upstream-pr upstream-pr upstream-prompt '' example/remote-repo &&
  [[ "$(git -C "$WORK/existing worktree" rev-parse HEAD)" == "$local_sha" ]] &&
  [[ "$(cat "$WORK/existing worktree/untracked")" == unfinished ]] &&
  grep -Fqx 'group=Attention branch=feature/fork new=false argc=3' "$DISPATCH_LOG"; then
  ok "adopts an existing worktree without losing commits or untracked files"
else
  bad "adopts an existing worktree without losing commits or untracked files"
fi
git -C "$REPO" remote add fork https://github.com/head-owner/head-repo.git
git -C "$REPO" remote set-url origin https://github.com/example/remote-repo.git
: >"$DISPATCH_LOG"
if run_attention github "$REPO" 63 attention/upstream-pr upstream-pr upstream-prompt '' example/remote-repo &&
  [[ "$(git -C "$WORK/existing worktree" rev-parse HEAD)" == "$local_sha" ]] &&
  grep -Fqx 'group=Attention branch=feature/fork new=false argc=3' "$DISPATCH_LOG"; then
  ok "adopts an upstream worktree containing the fetched fork PR head"
else
  bad "adopts an upstream worktree containing the fetched fork PR head"
fi
git -C "$REPO" remote set-url origin https://github.com/head-owner/head-repo.git
git -C "$REPO" remote remove fork
rm "$WORK/existing worktree/untracked"
git -C "$REPO" worktree remove "$WORK/existing worktree"
git -C "$REPO" config "url.$WORK/head.insteadOf" https://github.com/head-owner/head-repo.git

git -C "$REPO" update-ref refs/heads/feature/fork "$stale_sha"
: >"$DISPATCH_LOG"
if run_attention github "$REPO" 63 attention/upstream-pr upstream-pr upstream-prompt '' example/remote-repo &&
  [[ "$(git -C "$REPO" rev-parse refs/heads/feature/fork)" == "$head_sha" ]] &&
  grep -Fqx 'group=Attention branch=feature/fork new=false argc=3' "$DISPATCH_LOG"; then
  ok "fast-forwards an unattached PR branch behind the fetched head"
else
  bad "fast-forwards an unattached PR branch behind the fetched head"
fi
git -C "$REPO" update-ref refs/heads/feature/fork "$local_sha"
: >"$DISPATCH_LOG"
if run_attention github "$REPO" 63 attention/upstream-pr upstream-pr upstream-prompt '' example/remote-repo >"$WORK/diverged-head.out" 2>&1; then
  bad "rejects a divergent actual PR branch without overwriting it"
elif [[ ! -s "$DISPATCH_LOG" ]] &&
  [[ "$(git -C "$REPO" rev-parse refs/heads/feature/fork)" == "$local_sha" ]]; then
  ok "rejects a divergent actual PR branch without overwriting it"
else
  bad "rejects a divergent actual PR branch without overwriting it"
fi

export ATTENTION_MODE=issue
: >"$DISPATCH_LOG"
if run_attention github "$REPO" 64 attention/upstream-issue upstream-issue upstream-prompt '' example/remote-repo &&
  grep -Fqx 'group=Attention branch=attention/upstream-issue new=true argc=3' "$DISPATCH_LOG"; then
  ok "looks up upstream issues in the requested repository rather than the fork"
else
  bad "looks up upstream issues in the requested repository rather than the fork"
fi
unset ATTENTION_MODE ATTENTION_GIT_BIN ATTENTION_EXPECTED_REPO

export ATTENTION_MODE=pr
: >"$DISPATCH_LOG"
run_attention github "$REPO" 63 attention/pr-63 pr-title base-prompt '' example/remote-repo
unset ATTENTION_MODE
if grep -Fqx 'tool=omp' "$DISPATCH_LOG" &&
  grep -Fqx 'group=Attention branch=feature/fork new=false argc=3' "$DISPATCH_LOG"; then
  ok "keeps the default agent for unconfigured repos"
else
  bad "keeps the default agent for unconfigured repos"
  cat "$DISPATCH_LOG" >&2
fi


printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
