#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/dot_local/bin/executable_chezmoi-deploy"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-deploy-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/bin"
cat >"$WORK/bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  source-path) printf '%s\n' "$DEPLOY_TEST_PRIMARY" ;;
  apply) printf '%s\n' "$*" >>"$DEPLOY_TEST_LOG" ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$WORK/bin/chezmoi"

setup() {
  local name="$1"
  TEST_DIR="$WORK/$name"
  PRIMARY="$TEST_DIR/primary"
  FEATURE="$TEST_DIR/feature"
  LOG="$TEST_DIR/apply.log"
  mkdir -p "$TEST_DIR"
  git init -q -b main "$PRIMARY"
  git -C "$PRIMARY" config user.name 'Deploy Test'
  git -C "$PRIMARY" config user.email 'deploy@example.invalid'
  printf 'base\n' >"$PRIMARY/shared"
  git -C "$PRIMARY" add shared
  git -C "$PRIMARY" commit -qm base
  git init -q --bare "$TEST_DIR/origin.git"
  git -C "$PRIMARY" remote add origin "$TEST_DIR/origin.git"
  git -C "$PRIMARY" push -q origin main
  git -C "$PRIMARY" worktree add -q -b feature "$FEATURE"
  : >"$LOG"
}

run_deploy() {
  (cd "$PRIMARY" && PATH="$WORK/bin:$PATH" DEPLOY_TEST_PRIMARY="$PRIMARY" DEPLOY_TEST_LOG="$LOG" _CHEZMOI_DEPLOY_LOCKED=1 bash "$SCRIPT" feature)
}

assert_deployed() {
  git -C "$PRIMARY" merge-base --is-ancestor main feature
  [[ "$(git -C "$PRIMARY" rev-parse main)" = "$(git -C "$PRIMARY" rev-parse feature)" ]]
  [[ "$(git --git-dir="$TEST_DIR/origin.git" rev-parse main)" = "$(git -C "$PRIMARY" rev-parse main)" ]]
  [[ "$(cat "$LOG")" = 'apply --force --no-tty' ]]
}

setup fast_forward
printf 'feature\n' >"$FEATURE/feature"
git -C "$FEATURE" add feature
git -C "$FEATURE" commit -qm feature
run_deploy
assert_deployed
printf '  ok   fast-forward applies and pushes once\n'

setup stale_branch
printf 'feature\n' >"$FEATURE/feature"
git -C "$FEATURE" add feature
git -C "$FEATURE" commit -qm feature
printf 'main\n' >"$PRIMARY/main-file"
git -C "$PRIMARY" add main-file
git -C "$PRIMARY" commit -qm main-change
before_main="$(git -C "$PRIMARY" rev-parse main)"
run_deploy
assert_deployed
[[ "$before_main" != "$(git -C "$PRIMARY" rev-parse main)" ]]
[[ -f "$FEATURE/main-file" ]]
printf '  ok   stale worktree rebases and deploys in one invocation\n'

setup conflict
printf 'feature\n' >"$FEATURE/shared"
git -C "$FEATURE" add shared
git -C "$FEATURE" commit -qm feature
before_feature="$(git -C "$FEATURE" rev-parse HEAD)"
printf 'main\n' >"$PRIMARY/shared"
git -C "$PRIMARY" add shared
git -C "$PRIMARY" commit -qm main-change
before_main="$(git -C "$PRIMARY" rev-parse main)"
if run_deploy; then
  echo '  FAIL conflict must not deploy' >&2
  exit 1
fi
[[ "$(git -C "$PRIMARY" rev-parse main)" = "$before_main" ]]
[[ "$(git -C "$FEATURE" rev-parse HEAD)" = "$before_feature" ]]
[[ -z "$(git -C "$FEATURE" status --porcelain)" ]]
[[ ! -s "$LOG" ]]
[[ "$(git --git-dir="$TEST_DIR/origin.git" rev-parse main)" = "$(git -C "$PRIMARY" rev-parse main~1)" ]]
printf '  ok   conflict restores branch and does not deploy\n'

setup dirty_worktree
printf 'feature\n' >"$FEATURE/feature"
git -C "$FEATURE" add feature
git -C "$FEATURE" commit -qm feature
printf 'uncommitted\n' >"$FEATURE/untracked"
printf 'main\n' >"$PRIMARY/main-file"
git -C "$PRIMARY" add main-file
git -C "$PRIMARY" commit -qm main-change
if run_deploy; then
  echo '  FAIL dirty worktree must not rebase' >&2
  exit 1
fi
[[ -f "$FEATURE/untracked" && ! -s "$LOG" ]]
printf '  ok   dirty feature worktree remains untouched\n'

setup unassigned_branch
printf 'feature\n' >"$FEATURE/feature"
git -C "$FEATURE" add feature
git -C "$FEATURE" commit -qm feature
git -C "$PRIMARY" worktree remove "$FEATURE"
printf 'main\n' >"$PRIMARY/main-file"
git -C "$PRIMARY" add main-file
git -C "$PRIMARY" commit -qm main-change
run_deploy
git -C "$PRIMARY" merge-base --is-ancestor feature main
[[ "$(cat "$LOG")" = 'apply --force --no-tty' ]]
printf '  ok   unassigned local branch rebases and deploys\n'
