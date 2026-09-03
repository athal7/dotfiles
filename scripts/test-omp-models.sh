#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/omp-models-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0
fail=0
ok() { printf '  ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  FAIL %s\n' "$1"; fail=$((fail + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1 ($2)"; else bad "$1 (want '$3' got '$2')"; fi; }

DATA="$WORK/local.yaml"
MODELS="$WORK/models.yml"
AGENT_DIR="$WORK/agent"
BIN="$WORK/bin"
mkdir -p "$BIN"
cat > "$BIN/security" <<'EOF'
#!/usr/bin/env bash
exit 44
EOF
chmod +x "$BIN/security"
cp "$REPO_ROOT/local.yaml.example" "$DATA"
PATH="$BIN:$PATH" chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/models.yml" > "$MODELS"

check "omits OpenRouter without a key" "$(yq -r '(.providers // {}) | has("openrouter")' "$MODELS")" false
check "renders the local provider" "$(yq -r '.providers.mlx.models[0].id' "$MODELS")" default_model
OPENROUTER_MODELS="$WORK/openrouter-models.yml"
OPENROUTER_API_KEY=test-key chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/models.yml" > "$OPENROUTER_MODELS"
check "renders OpenRouter with a key" "$(yq -r '(.providers // {}) | has("openrouter")' "$OPENROUTER_MODELS")" true
OPENROUTER_LOCAL_MODELS="$WORK/openrouter-local-models.yml"
echo 'openrouter_api_key: local-test-key' >> "$DATA"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/models.yml" > "$OPENROUTER_LOCAL_MODELS"
check "renders OpenRouter from local.yaml" "$(yq -r '(.providers // {}) | has("openrouter")' "$OPENROUTER_LOCAL_MODELS")" true

mkdir -p "$AGENT_DIR"
cp "$MODELS" "$AGENT_DIR/models.yml"
models="$(PI_CODING_AGENT_DIR="$AGENT_DIR" omp models mlx --json)"
check "OMP enables the local provider" "$(printf '%s' "$models" | jq -r '.models[0].provider')" mlx

printf '\n== summary: %s passed, %s failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
