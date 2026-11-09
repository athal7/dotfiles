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

# Render the real template against only this test's data. chezmoi merges every
# file under .chezmoidata/, so the machine-local (gitignored) local.yaml would
# otherwise leak its own orgs into the render and make the results depend on
# whoever runs the test. A throwaway source dir keeps it hermetic while still
# exercising the shipped template verbatim.
render_config() {
  local src="$WORK/src"
  rm -rf "$src"
  mkdir -p "$src/.chezmoidata" "$src/dot_config/attention"
  cp "$REPO_ROOT/dot_config/attention/config.json.tmpl" "$src/dot_config/attention/"
  cp "$DATA" "$src/.chezmoidata/local.yaml"
  chezmoi cat -S "$src" "$HOME/.config/attention/config.json" >"$RENDERED"
}
cat >"$DATA" <<'EOF'
orgs:
  your-work-org:
    attention: Work
  your-personal-org:
    kb_eligible: false
EOF
render_config

if jq -e . "$RENDERED" >/dev/null; then
  ok "renders valid JSON"
else
  bad "renders valid JSON"
fi
check "leaves session agent selection to AoE" \
  test "$(jq -r 'has("session")' "$RENDERED")" = false

cat >"$DATA" <<'EOF'
orgs:
  your-work-org:
    attention: Work
  your-other-org:
    attention_agent: freebuff
EOF
render_config
check "ignores a retired per-org attention agent setting" \
  test "$(jq -r 'has("session")' "$RENDERED")" = false

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
