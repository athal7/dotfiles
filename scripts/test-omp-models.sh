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
EMPTY_MCP="$WORK/empty-mcp.json"
KB_ENRICH_MCP="$WORK/kb-enrich-mcp.json"
CONFIG="$WORK/config.yml"
AOE="$WORK/aoe.toml"
ZSHENV="$WORK/zshenv"
AGENT_DIR="$WORK/agent"
BIN="$WORK/bin"
mkdir -p "$BIN"
cat > "$BIN/security" <<'EOF'
#!/usr/bin/env bash
exit 44
EOF
chmod +x "$BIN/security"
cp "$REPO_ROOT/local.yaml.example" "$DATA"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/mcp.json" > "$EMPTY_MCP"
yq -i '.runlayer.bigquery_mcp_url = "https://bigquery.example.test/mcp" | .runlayer.pagerduty_mcp_url = "https://pagerduty.example.test/mcp"' "$DATA"
PATH="$BIN:$PATH" chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/models.yml" > "$MODELS"
PATH="$BIN:$PATH" chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/config.yml" > "$CONFIG"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.agent-of-empires/config.toml" > "$AOE"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.zshenv" > "$ZSHENV"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/mcp.json" > "$MCP"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.omp/agent/kb-enrich-mcp.json" > "$KB_ENRICH_MCP"
PLUGIN_INSTALL="$WORK/plugins-aoe.sh"
chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$DATA" --file "$REPO_ROOT/.chezmoiscripts/run_onchange_after_plugins-aoe.sh.tmpl" > "$PLUGIN_INSTALL"
check "preserves git push approval" "$(yq -r '.bash.patterns[] | select(.match == "git push*") | .approval' "$CONFIG")" prompt
check "requires browser approval" "$(yq -r '.tools.approval.browser' "$CONFIG")" prompt
check "preserves browser headless override" "$(yq -r '.browser.headless' "$CONFIG")" false
check "preserves browser relay override" "$(yq -r '.browser.relay' "$CONFIG")" true
check "preserves unexpected stop detection override" "$(yq -r '.features.unexpectedStopDetection' "$CONFIG")" smart
check "preserves OpenAI Codex code mode override" "$(yq -r '.providers.openai-codex.codeMode' "$CONFIG")" auto
check "preserves task advisor override" "$(yq -r '.task.agentAdvisor.task' "$CONFIG")" off
check "omits empty retry configuration" "$(yq -r '. | has("retry")' "$CONFIG")" false
STALE_AOE="$WORK/stale-aoe.toml"
printf '[plugins."agent-of-empires.github"]\nenabled = true\n[host_hooks]\nbefore_session = ["stale-router"]\nafter_session = ["keep-hook"]\n[session.agent_command_override]\nomp = "stale-omp"\nother = "keep-agent"\n' \
  | chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$DATA" --with-stdin --file "$REPO_ROOT/dot_agent-of-empires/modify_config.toml" > "$STALE_AOE"
check "removes the stale AoE model-routing hook" "$(yq -p=toml -o=json '.host_hooks | has("before_session")' "$STALE_AOE")" false
check "preserves unrelated AoE hooks" "$(yq -p=toml -o=json '.host_hooks.after_session[0]' "$STALE_AOE" | jq -r '.')" keep-hook
check "removes the stale AoE OMP override" "$(yq -p=toml -o=json '.session.agent_command_override | has("omp")' "$STALE_AOE")" false
check "preserves unrelated AoE agent overrides" "$(yq -p=toml -o=json '.session.agent_command_override.other' "$STALE_AOE" | jq -r '.')" keep-agent
check "preserves the configured AoE GitHub plugin" "$(yq -p=toml -o=json '.plugins | has("agent-of-empires.github")' "$STALE_AOE")" true
if bash -n "$PLUGIN_INSTALL"; then
  plugin_install_valid=true
else
  plugin_install_valid=false
fi
check "renders the configured AoE plugin installer" "$plugin_install_valid" true
check "installs the configured AoE GitHub plugin" "$(grep -Fxc '  if ! aoe plugin install gh:agent-of-empires/plugin-github --yes < /dev/null; then' "$PLUGIN_INSTALL")" 1
check "keeps foundational MCP servers enabled" "$(jq '[.mcpServers.context7.enabled, .mcpServers.cq.enabled] | all(. != false)' "$MCP")" true
check "disables integration MCP servers by default" "$(jq '[.mcpServers | to_entries[] | select(.key != "context7" and .key != "cq") | .value.enabled == false] | all' "$MCP")" true
check "keeps empty Runlayer MCP URLs as placeholders" "$(jq '[.mcpServers["runlayer-bigquery"].url, .mcpServers["runlayer-pagerduty"].url] == ["${RUNLAYER_BIGQUERY_MCP_URL}", "${RUNLAYER_PAGERDUTY_MCP_URL}"]' "$EMPTY_MCP")" true
runlayer_mcp_urls=(
  "runlayer-bigquery https://bigquery.example.test/mcp"
  "runlayer-pagerduty https://pagerduty.example.test/mcp"
)
for connector_and_url in "${runlayer_mcp_urls[@]}"; do
  read -r connector url <<< "$connector_and_url"
  check "renders $connector MCP entry" "$(jq --arg connector "$connector" '.mcpServers | has($connector)' "$MCP")" true
  check "renders $connector MCP URL" "$(jq -r --arg connector "$connector" '.mcpServers[$connector].url' "$MCP")" "$url"
done
rendered_runlayer_environment="$(yq -p=toml -o=json '.environment' "$AOE" | jq -r '.[]' | sort | paste -sd ' ' -)"
check "exports configured Runlayer MCP URL variables to AoE sessions" "$rendered_runlayer_environment" "RUNLAYER_BIGQUERY_MCP_URL=https://bigquery.example.test/mcp RUNLAYER_PAGERDUTY_MCP_URL=https://pagerduty.example.test/mcp"
if bash -n "$ZSHENV"; then zshenv_valid=true; else zshenv_valid=false; fi
check "renders a valid shell environment" "$zshenv_valid" true
rendered_runlayer_shell_environment="$(grep '^export RUNLAYER_.*_MCP_URL=' "$ZSHENV" | sort | paste -sd ' ' -)"
check "exports configured Runlayer MCP URLs to shell sessions" "$rendered_runlayer_shell_environment" "export RUNLAYER_BIGQUERY_MCP_URL=\"https://bigquery.example.test/mcp\" export RUNLAYER_PAGERDUTY_MCP_URL=\"https://pagerduty.example.test/mcp\""
check "limits KB enrichment to its collector MCP allowlist" "$(jq -r '.mcpServers | keys | sort | join(" ")' "$KB_ENRICH_MCP")" "cq linear runlayer-atlassian runlayer-gcalendar runlayer-slack runlayer-zoom"
check "renders the Calendar MCP URL" "$(jq -r '.mcpServers["runlayer-gcalendar"].url' "$KB_ENRICH_MCP")" "\${RUNLAYER_GCALENDAR_MCP_URL}"
check "enables the Calendar MCP server" "$(jq -r '.mcpServers["runlayer-gcalendar"].enabled' "$KB_ENRICH_MCP")" true
check "explicitly enables every KB enrichment MCP server" "$(jq '[.mcpServers[].enabled] | all(. == true)' "$KB_ENRICH_MCP")" true
check "renders the local provider" "$(yq -r '.providers.gguf.models[0].id' "$MODELS")" Qwen3-30B-A3B-Instruct-2507
check "renders the configured context window" "$(yq -r '.providers.gguf.models[0].contextWindow' "$MODELS")" 32768
check "preserves the local output limit" "$(yq -r '.providers.gguf.models[0].maxTokens' "$MODELS")" 8192
check "renders the GGUF compaction model" "$(yq -r '.providers.gguf.models[0].compactionModel' "$MODELS")" openai-codex/gpt-5.6-terra
check "disables unsupported reasoning" "$(yq -r '.providers.gguf.models[0].reasoning' "$MODELS")" false

CUSTOM_DATA="$WORK/custom-local.yaml"
CUSTOM_MODELS="$WORK/custom-models.yml"
LAUNCH_AGENTS="$WORK/agents.yaml"
cp "$DATA" "$CUSTOM_DATA"
yq -i '.local_model.context_window = 40960' "$CUSTOM_DATA"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" "$HOME/.omp/agent/models.yml" > "$CUSTOM_MODELS"
chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$CUSTOM_DATA" --file "$REPO_ROOT/dot_config/launchd-yaml/agents.yaml.tmpl" > "$LAUNCH_AGENTS"
check "propagates the configured provider context window" "$(yq -r '.providers.gguf.models[0].contextWindow' "$CUSTOM_MODELS")" 40960
check "propagates the configured server context window" "$(yq -o=json '.launchagents."llama-server".ProgramArguments' "$LAUNCH_AGENTS" | jq -r '. as $args | $args[($args | index("--ctx-size")) + 1]')" 40960
check "gives daily maintenance the KB scratch MCP overlay" "$(yq -r '.launchagents."aoe-daily-maintenance".EnvironmentVariables.AOE_OMP_PROJECT_MCP_CONFIG' "$LAUNCH_AGENTS")" "\$HOME/.omp/agent/kb-enrich-mcp.json"
check "pins daily maintenance to the lower-cost model role" "$(yq -r '.launchagents."aoe-daily-maintenance".EnvironmentVariables.AOE_OMP_MODEL' "$LAUNCH_AGENTS")" @smol
check "invokes the combined daily command" "$(yq -r '.launchagents."aoe-daily-maintenance".ProgramArguments[2]' "$LAUNCH_AGENTS")" /daily-maintenance
check "runs daily maintenance at the original enrichment time" "$(yq -o=json '.launchagents."aoe-daily-maintenance".StartCalendarInterval' "$LAUNCH_AGENTS" | jq '[.[].Minute] | unique | if . == [0] then 0 else . end')" 0
check "removes superseded scheduled sessions" "$(yq -o=json '.launchagents' "$LAUNCH_AGENTS" | jq 'has("aoe-kb-enrich") or has("aoe-fix-prod-errors") or has("aoe-audit")')" false
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
