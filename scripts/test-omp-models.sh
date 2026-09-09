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
MCP="$WORK/mcp.json"
KB_PROFILE_MCP="$WORK/kb-enrich-mcp.json"
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
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/mcp.json" > "$MCP"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/profiles/kb-enrich/agent/mcp.json" > "$KB_PROFILE_MCP"
KB_PROFILE_COMMANDS_LINK="$(chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/profiles/kb-enrich/agent/commands")"
expected_roles=(commit default designer plan slow smol task tiny vision)
rendered_roles="$(yq -o=json '.modelRoles | keys | sort' "$CONFIG" | jq -r 'join(" ")')"
check "renders every model role" "$rendered_roles" "${expected_roles[*]}"
check "routes default role to cloud sol" "$(yq -r '.modelRoles.default' "$CONFIG")" openai-codex/gpt-5.6-sol
check "routes smol role to cloud terra" "$(yq -r '.modelRoles.smol' "$CONFIG")" openai-codex/gpt-5.6-terra
check "routes designer role through vision alias" "$(yq -r '.modelRoles.designer' "$CONFIG")" @vision
check "uses local tiny utility model" "$(yq -r '.providers.tinyModel' "$CONFIG")" lfm2-350m
check "uses local thinking utility model" "$(yq -r '.providers.autoThinkingModel' "$CONFIG")" lfm2-350m
check "sets shared prewalk destination" "$(yq -r '.prewalk.into' "$CONFIG")" openai-codex/gpt-5.6-terra
check "enables lazy tool loading" "$(yq -r '.tools.xdev' "$CONFIG")" true
check "keeps foundational MCP servers enabled" "$(jq '[.mcpServers.context7.enabled, .mcpServers.cq.enabled] | all(. != false)' "$MCP")" true
check "disables integration MCP servers by default" "$(jq '[.mcpServers | to_entries[] | select(.key != "context7" and .key != "cq") | .value.enabled == false] | all' "$MCP")" true
check "limits KB profile to its collector MCP allowlist" "$(jq -r '.mcpServers | keys | sort | join(" ")' "$KB_PROFILE_MCP")" "cq linear runlayer-atlassian runlayer-slack runlayer-zoom"
check "enables every KB profile MCP server" "$(jq '[.mcpServers[].enabled] | all(. != false)' "$KB_PROFILE_MCP")" true
check "links KB profile commands to the default command set" "$KB_PROFILE_COMMANDS_LINK" ../../../agent/commands
LEGACY_DATA="$WORK/legacy-local.yaml"
LEGACY_CONFIG="$WORK/legacy-config.yml"
cp "$DATA" "$LEGACY_DATA"
yq -i '.prewalk.into = .model_class.default' "$LEGACY_DATA"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$LEGACY_DATA" "$HOME/.omp/agent/config.yml" > "$LEGACY_CONFIG"
check "migrates legacy Sol prewalk target to Terra" "$(yq -r '.prewalk.into' "$LEGACY_CONFIG")" openai-codex/gpt-5.6-terra
STALE_CONFIG="$WORK/stale-config.yml"
printf 'prewalk:\n  enabled: false\n  into: stale/model\n  custom: preserved\nproviders:\n  tinyModel: stale-tiny\n  autoThinkingModel: stale-thinking\n  customModel: preserved\n' \
  | chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$DATA" --with-stdin --file "$REPO_ROOT/dot_omp/private_agent/modify_private_config.yml" > "$STALE_CONFIG"
check "modifier replaces stale prewalk enabled" "$(yq -r '.prewalk.enabled' "$STALE_CONFIG")" true
check "modifier replaces stale prewalk destination" "$(yq -r '.prewalk.into' "$STALE_CONFIG")" openai-codex/gpt-5.6-terra
check "modifier replaces stale tiny utility model" "$(yq -r '.providers.tinyModel' "$STALE_CONFIG")" lfm2-350m
check "modifier replaces stale thinking utility model" "$(yq -r '.providers.autoThinkingModel' "$STALE_CONFIG")" lfm2-350m
check "modifier preserves unrelated prewalk settings" "$(yq -r '.prewalk.custom' "$STALE_CONFIG")" preserved
check "modifier preserves unrelated provider settings" "$(yq -r '.providers.customModel' "$STALE_CONFIG")" preserved
check "enables task prewalk" "$(yq -r '.task.prewalk' "$CONFIG")" true
check "routes planner agent through plan role" "$(yq -r '.task.agentModelOverrides.planner' "$CONFIG")" @plan
check "routes designer agent through designer role" "$(yq -r '.task.agentModelOverrides.designer' "$CONFIG")" @designer
check "routes reviewer agent through slow role" "$(yq -r '.task.agentModelOverrides.reviewer' "$CONFIG")" @slow
check "routes sonic agent through smol role" "$(yq -r '.task.agentModelOverrides.sonic' "$CONFIG")" @smol
check "keeps advisor enabled" "$(yq -r '.advisor.enabled' "$CONFIG")" true
check "routes advisor through local model" "$(yq -r '.advisor.model' "$CONFIG")" gguf/Qwen3-30B-A3B-Instruct-2507
check "disables advisor for subagents" "$(yq -r '.advisor.subagents' "$CONFIG")" false
check "disables automatic session resume" "$(yq -r '.autoResume' "$CONFIG")" false
check "selects Snapcompact compaction" "$(yq -r '.compaction.strategy' "$CONFIG")" snapcompact
check "removes unsupported compaction order" "$(yq -r '.compaction | has("methodOrder")' "$CONFIG")" false

check "renders the local provider" "$(yq -r '.providers.gguf.models[0].id' "$MODELS")" Qwen3-30B-A3B-Instruct-2507
check "renders the configured context window" "$(yq -r '.providers.gguf.models[0].contextWindow' "$MODELS")" 32768
check "preserves the local output limit" "$(yq -r '.providers.gguf.models[0].maxTokens' "$MODELS")" 8192
check "renders the GGUF compaction model" "$(yq -r '.providers.gguf.models[0].compactionModel' "$MODELS")" openai-codex/gpt-5.6-terra
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
CUSTOM_CONFIG="$WORK/custom-config.yml"
CUSTOM_AOE="$WORK/custom-aoe.toml"
yq -i '.prewalk.into = "test/prewalk-model"' "$CUSTOM_DATA"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" "$HOME/.omp/agent/config.yml" > "$CUSTOM_CONFIG"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" "$HOME/.agent-of-empires/config.toml" > "$CUSTOM_AOE"
check "propagates shared prewalk destination to OMP config" "$(yq -r '.prewalk.into' "$CUSTOM_CONFIG")" test/prewalk-model
check "propagates shared prewalk destination to AOE override" "$(yq -p=toml -o=json '.session.agent_command_override.omp' "$CUSTOM_AOE" | jq -r '.')" "omp --prewalk-into test/prewalk-model"
DISABLED_CONFIG="$WORK/disabled-config.yml"
DISABLED_AOE="$WORK/disabled-aoe.toml"
yq -i '.prewalk.enabled = false' "$CUSTOM_DATA"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" "$HOME/.omp/agent/config.yml" > "$DISABLED_CONFIG"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" "$HOME/.agent-of-empires/config.toml" > "$DISABLED_AOE"
check "propagates disabled prewalk to OMP config" "$(yq -r '.prewalk.enabled' "$DISABLED_CONFIG")" false
check "removes AOE override when prewalk is disabled" "$(yq -p=toml -o=json '.session | has("agent_command_override")' "$DISABLED_AOE")" false
DISABLED_AOE_WITH_OTHER="$WORK/disabled-aoe-with-other.toml"
printf '[session.agent_command_override]\nother = "other-agent"\nomp = "stale-omp"\n' \
  | chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" --with-stdin --file "$REPO_ROOT/dot_agent-of-empires/modify_config.toml" > "$DISABLED_AOE_WITH_OTHER"
check "preserves unrelated AOE overrides" "$(yq -p=toml -o=json '.session.agent_command_override.other' "$DISABLED_AOE_WITH_OTHER" | jq -r '.')" other-agent
check "removes only the OMP AOE override" "$(yq -p=toml -o=json '.session.agent_command_override | has("omp")' "$DISABLED_AOE_WITH_OTHER")" false
check "runs KB enrichment with its isolated OMP profile" "$(yq -r '.launchagents."aoe-kb-enrich".EnvironmentVariables.AOE_OMP_PROFILE' "$LAUNCH_AGENTS")" kb-enrich
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
