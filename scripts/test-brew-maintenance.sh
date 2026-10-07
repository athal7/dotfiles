#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/brew-maintenance-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

mkdir -p "$WORK/bin"
cat >"$WORK/bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$BREW_TEST_LOG"
case "$*" in
  update) exit "${BREW_UPDATE_STATUS:-0}" ;;
  'upgrade --no-ask') exit "${BREW_UPGRADE_STATUS:-0}" ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$WORK/bin/brew"

SCRIPT="$REPO_ROOT/dot_local/bin/executable_brew-maintenance"
LOG="$WORK/brew.log"
pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }

: >"$LOG"
if PATH="$WORK/bin:$PATH" BREW_TEST_LOG="$LOG" "$SCRIPT"; then
  if [[ "$(<"$LOG")" == $'update\nupgrade --no-ask' ]]; then
    ok "updates metadata before unattended upgrade"
  else
    bad "updates metadata before unattended upgrade"
  fi
else
  bad "runs update and upgrade successfully"
fi

: >"$LOG"
if PATH="$WORK/bin:$PATH" BREW_TEST_LOG="$LOG" BREW_UPDATE_STATUS=1 "$SCRIPT" >/dev/null 2>&1; then
  bad "propagates update failure"
else
  if [[ "$(<"$LOG")" == update ]]; then
    ok "stops before upgrade when update fails"
  else
    bad "stops before upgrade when update fails"
  fi
fi

: >"$LOG"
if PATH="$WORK/bin:$PATH" BREW_TEST_LOG="$LOG" BREW_UPGRADE_STATUS=1 "$SCRIPT" >/dev/null 2>&1; then
  bad "propagates upgrade failure"
else
  if [[ "$(<"$LOG")" == $'update\nupgrade --no-ask' ]]; then
    ok "reports upgrade failure after update"
  else
    bad "reports upgrade failure after update"
  fi
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
