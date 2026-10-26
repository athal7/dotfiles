#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/attention-config-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check() { local label=$1; shift; if "$@"; then ok "$label"; else bad "$label"; fi; }

DATA="$WORK/local.yaml"
RENDERED="$WORK/attention.json"
cat >"$DATA" <<'EOF'
orgs:
  your-work-org:
    attention: Work
  your-personal-org:
    kb_eligible: false
EOF
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.config/attention/config.json" >"$RENDERED"

if jq -e . "$RENDERED" >/dev/null; then
  ok "renders valid JSON"
else
  bad "renders valid JSON"
fi
check "keeps the configured dashboard groups" \
  test "$(jq -r '.dashboard.groups | length' "$RENDERED")" = 3
check "routes personal-org repos to freebuff" \
  test "$(jq -c '.session.agents' "$RENDERED")" = '[{"repo":"your-personal-org/*","tool":"freebuff"}]'
check "leaves work orgs on AoE's default agent" \
  test "$(jq -r '[.session.agents[].repo] | index("your-work-org/*")' "$RENDERED")" = null

cat >"$DATA" <<'EOF'
orgs:
  your-work-org:
    attention: Work
EOF
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.config/attention/config.json" >"$RENDERED"
check "renders no agent overrides when only work orgs are configured" \
  test "$(jq -c '.session.agents' "$RENDERED")" = '[]'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
