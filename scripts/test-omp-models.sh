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
CONFIG="$WORK/config.yml"
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
PATH="$BIN:$PATH" chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/config.yml" > "$CONFIG"
check "disables automatic session resume" "$(yq -r '.autoResume' "$CONFIG")" false
check "selects Snapcompact compaction" "$(yq -r '.compaction.strategy' "$CONFIG")" snapcompact
check "removes unsupported compaction order" "$(yq -r '.compaction | has("methodOrder")' "$CONFIG")" false

check "omits OpenRouter without a key" "$(yq -r '(.providers // {}) | has("openrouter")' "$MODELS")" false
check "renders the local provider" "$(yq -r '.providers.gguf.models[0].id' "$MODELS")" default_model
check "renders the configured context window" "$(yq -r '.providers.gguf.models[0].contextWindow' "$MODELS")" 32768
check "preserves the local output limit" "$(yq -r '.providers.gguf.models[0].maxTokens' "$MODELS")" 8192
check "disables unsupported reasoning" "$(yq -r '.providers.gguf.models[0].reasoning' "$MODELS")" false
check "disables automatic session resume" "$(yq -r '.autoResume' "$CONFIG")" false
check "selects Snapcompact compaction" "$(yq -r '.compaction.strategy' "$CONFIG")" snapcompact
CUSTOM_DATA="$WORK/custom-local.yaml"
CUSTOM_MODELS="$WORK/custom-models.yml"
LAUNCH_AGENTS="$WORK/agents.yaml"
cp "$DATA" "$CUSTOM_DATA"
yq -i '.local_model.context_window = 40960' "$CUSTOM_DATA"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" "$HOME/.omp/agent/models.yml" > "$CUSTOM_MODELS"
chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" --file "$REPO_ROOT/dot_config/launchd-yaml/agents.yaml.tmpl" > "$LAUNCH_AGENTS"
check "propagates the configured provider context window" "$(yq -r '.providers.gguf.models[0].contextWindow' "$CUSTOM_MODELS")" 40960
check "propagates the configured server context window" "$(yq -o=json '.launchagents."llama-server".ProgramArguments' "$LAUNCH_AGENTS" | jq -r '. as $args | $args[($args | index("--ctx-size")) + 1]')" 40960
check "routes the local server through llama.cpp" "$(yq -r '.launchagents."llama-server".ProgramArguments[0]' "$LAUNCH_AGENTS")" /opt/homebrew/bin/llama-server
check "enables the llama prompt cache" "$(yq -o=json '.launchagents."llama-server".ProgramArguments' "$LAUNCH_AGENTS" | jq -r 'index("--cache-prompt") != null')" true
check "preserves a single llama request slot" "$(yq -o=json '.launchagents."llama-server".ProgramArguments' "$LAUNCH_AGENTS" | jq -r '. as $args | $args[($args | index("--parallel")) + 1]')" 1
check "propagates the llama cache limit" "$(yq -o=json '.launchagents."llama-server".ProgramArguments' "$LAUNCH_AGENTS" | jq -r '. as $args | $args[($args | index("--cache-ram")) + 1]')" 3G
check "enables llama metrics" "$(yq -o=json '.launchagents."llama-server".ProgramArguments' "$LAUNCH_AGENTS" | jq -r 'index("--metrics") != null')" true
OPENROUTER_MODELS="$WORK/openrouter-models.yml"
OPENROUTER_API_KEY=test-key chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/models.yml" > "$OPENROUTER_MODELS"
check "renders OpenRouter with a key" "$(yq -r '(.providers // {}) | has("openrouter")' "$OPENROUTER_MODELS")" true
OPENROUTER_LOCAL_MODELS="$WORK/openrouter-local-models.yml"
echo 'openrouter_api_key: local-test-key' >> "$DATA"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/models.yml" > "$OPENROUTER_LOCAL_MODELS"
check "renders OpenRouter from local.yaml" "$(yq -r '(.providers // {}) | has("openrouter")' "$OPENROUTER_LOCAL_MODELS")" true

mkdir -p "$AGENT_DIR"
cp "$MODELS" "$AGENT_DIR/models.yml"
cp "$CONFIG" "$AGENT_DIR/config.yml"
auto_resume="$(PI_CODING_AGENT_DIR="$AGENT_DIR" omp config get autoResume --json | jq -r '.value')"
check "OMP accepts disabled automatic resume" "$auto_resume" false
models="$(PI_CODING_AGENT_DIR="$AGENT_DIR" omp models gguf --json)"
check "OMP enables the local provider" "$(printf '%s' "$models" | jq -r '.models[0].provider')" gguf

printf '\n== summary: %s passed, %s failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
