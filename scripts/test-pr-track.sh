#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/pr-track.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
mkdir -p "$HOME/.local/bin" "$WORK/bin"
cp "$ROOT/dot_local/bin/executable_pr-track" "$HOME/.local/bin/pr-track"
cp "$ROOT/dot_local/bin/executable_aoe-pr-track" "$HOME/.local/bin/aoe-pr-track"
REAL_GIT=$(command -v git)
export REAL_GIT TEST_ORIGIN="$WORK/origin.git"
cat > "$WORK/bin/git" <<'EOF'
#!/bin/sh
for arg in "$@"; do
  if [ "$arg" = fetch ]; then
    exec "$REAL_GIT" -c "url.file://$TEST_ORIGIN.insteadOf=https://github.com/example/project.git" "$@"
  fi
done
exec "$REAL_GIT" "$@"
EOF
cat > "$WORK/bin/gh" <<'EOF'
#!/bin/sh
[ "${GH_FAIL:-}" != 1 ] || exit 1
[ "${GH_HANG:-}" != 1 ] || exec sleep 30
case "$1 $2" in
  'api repos/'*) jq -n --arg sha "$(git rev-parse HEAD)" --argjson n "${PR_COUNT:-1}" --arg mode "${PR_MODE:-all}" '[range($n) | {state:(if $mode == "all" or . == 0 then "open" else "closed" end),head:{sha:$sha},number:42}]' | jq -r "$4" ;;
  'pr view') printf 'feature\texample\tproject\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$WORK/bin/gh" "$WORK/bin/git" "$HOME/.local/bin/pr-track" "$HOME/.local/bin/aoe-pr-track"
export PATH="$WORK/bin:$PATH"
repo="$WORK/repo with spaces"
git init -q -b main "$repo"
git -C "$repo" -c core.hooksPath=/dev/null commit -q --allow-empty -m initial
git -C "$repo" branch feature
git clone -q --bare "$repo" "$WORK/origin.git"
git -C "$repo" remote add origin https://github.com/example/project.git
git -C "$repo" branch -D feature >/dev/null
git -C "$repo" worktree add -q -b review "$WORK/review with spaces"
wt="$WORK/review with spaces"
(cd "$wt" && "$HOME/.local/bin/pr-track" 42)
[ "$(git -C "$wt" branch --show-current)" = feature ]
[ "$(git -C "$wt" rev-parse --abbrev-ref '@{upstream}')" = origin/feature ]
(cd "$wt" && "$HOME/.local/bin/pr-track" 42)
git -C "$wt" switch -q review
printf 'uncommitted\n' > "$wt/new-file"
if (cd "$wt" && "$HOME/.local/bin/pr-track" 42 >/dev/null 2>&1); then exit 1; fi
[ "$(git -C "$wt" branch --show-current)" = review ]
[ "$(cat "$wt/new-file")" = uncommitted ]
rm "$wt/new-file"
AOE_PROJECT_PATH="$wt" "$HOME/.local/bin/aoe-pr-track"
[ "$(git -C "$wt" branch --show-current)" = feature ]
git -C "$wt" switch -q review
GH_FAIL=1 AOE_PROJECT_PATH="$wt" "$HOME/.local/bin/aoe-pr-track"
[ "$(git -C "$wt" branch --show-current)" = review ]
PR_COUNT=2 AOE_PROJECT_PATH="$wt" "$HOME/.local/bin/aoe-pr-track"
[ "$(git -C "$wt" branch --show-current)" = review ]
PR_COUNT=100 PR_MODE=one AOE_PROJECT_PATH="$wt" "$HOME/.local/bin/aoe-pr-track"
[ "$(git -C "$wt" branch --show-current)" = review ]
GH_HANG=1 AOE_PROJECT_PATH="$wt" "$HOME/.local/bin/aoe-pr-track"
[ "$(git -C "$wt" branch --show-current)" = review ]
AOE_PROJECT_PATH="$repo" "$HOME/.local/bin/aoe-pr-track"
[ "$(git -C "$repo" branch --show-current)" = main ]
AOE_PROJECT_PATH="$WORK" "$HOME/.local/bin/aoe-pr-track"
if (cd "$wt" && "$HOME/.local/bin/pr-track" invalid >/dev/null 2>&1); then exit 1; fi
printf 'pr-track worktree scenarios passed\n'
