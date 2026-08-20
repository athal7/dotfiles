#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTER="$REPO_ROOT/dot_local/bin/executable_aoe-model-class"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/aoe-model-class-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (want '$3' got '$2')"; fi; }

TEST_HOME="$WORK/home"
TEST_SOURCE="$WORK/source"
mkdir -p "$TEST_HOME/.config/chezmoi" "$TEST_SOURCE/.chezmoidata"
cat > "$TEST_HOME/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "$TEST_SOURCE"
EOF
cat > "$TEST_SOURCE/.chezmoidata/local.yaml" <<'YAML'
orgs:
  acme:
    model_class:
      default: mlx/test
      plan: mlx/test
      slow: mlx/test
      smol: mlx/test
local_model:
  compaction_keep_recent_tokens: 1234
YAML

run_router() {
  (
    cd "$1"
    XDG_CONFIG_HOME="$TEST_HOME/.config" "$ROUTER"
  )
}

project="$WORK/project"
git init -q "$project"
git -C "$project" remote add origin git@github.com:acme/modelled.git
mkdir -p "$project/.omp"
cat > "$project/.omp/config.yml" <<'YAML'
disabledExtensions:
  - mcp:github
custom:
  preserved: true
modelRoles:
  default: prior/model
YAML

echo "== matching organization =="
run_router "$project" && status=0 || status=$?
check "matching organization exits zero" "$status" 0
check "writes configured default role" "$(yq -r '.modelRoles.default' "$project/.omp/config.yml")" "mlx/test"
check "writes configured plan role" "$(yq -r '.modelRoles.plan' "$project/.omp/config.yml")" "mlx/test"
check "writes compaction setting" "$(yq -r '.compaction.keepRecentTokens' "$project/.omp/config.yml")" 1234
check "preserves existing configuration" "$(yq -r '.custom.preserved' "$project/.omp/config.yml")" true
check "preserves disabled extensions" "$(yq -r '.disabledExtensions[0]' "$project/.omp/config.yml")" mcp:github

unknown="$WORK/unknown"
git init -q "$unknown"
git -C "$unknown" remote add origin git@github.com:other/modelled.git

echo "== unknown organization =="
run_router "$unknown" && status=0 || status=$?
check "unknown organization exits zero" "$status" 0
if [ ! -e "$unknown/.omp/config.yml" ]; then ok "unknown organization leaves no OMP config"; else bad "unknown organization leaves no OMP config"; fi

scratch="$WORK/scratch"
mkdir -p "$scratch"

echo "== scratch directory =="
run_router "$scratch" && status=0 || status=$?
check "scratch directory exits zero" "$status" 0
if [ ! -e "$scratch/.omp/config.yml" ]; then ok "scratch directory leaves no OMP config"; else bad "scratch directory leaves no OMP config"; fi

echo
printf '== summary: %s passed, %s failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
