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
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.config/omp/agent/mcp.json" > "$EMPTY_MCP"
yq -i '
  .runlayer.bigquery_mcp_url = "https://bigquery.example.test/mcp" |
  .runlayer.pagerduty_mcp_url = "https://pagerduty.example.test/mcp"
' "$DATA"
PATH="$BIN:$PATH" chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.config/omp/agent/models.yml" > "$MODELS"
PATH="$BIN:$PATH" chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.config/omp/agent/config.yml" > "$CONFIG"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.config/agent-of-empires/config.toml" > "$AOE"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.zshenv" > "$ZSHENV"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.config/omp/agent/mcp.json" > "$MCP"
chezmoi cat -S "$REPO_ROOT" --override-data-file "$DATA" "$HOME/.config/omp/agent/kb-enrich-mcp.json" > "$KB_ENRICH_MCP"
PLUGIN_INSTALL="$WORK/plugins-aoe.sh"
chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$DATA" --file "$REPO_ROOT/.chezmoiscripts/run_onchange_after_plugins-aoe.sh.tmpl" > "$PLUGIN_INSTALL"
check "renders managed browser headless mode" "$(yq -r '.browser.headless' "$CONFIG")" true
check "preserves browser relay override" "$(yq -r '.browser.relay' "$CONFIG")" true
check "preserves unexpected stop detection override" "$(yq -r '.features.unexpectedStopDetection' "$CONFIG")" smart
check "preserves OpenAI Codex code mode override" "$(yq -r '.providers.openai-codex.codeMode' "$CONFIG")" auto
check "routes native judgment to local OpenJev" "$(yq -r '.modelRoles.judge' "$CONFIG")" openjev/openjev-latest
check "preserves task advisor override" "$(yq -r '.task.agentAdvisor.task' "$CONFIG")" off
check "registers OpenJev with the native decision API" "$(yq -r ".providers.openjev.api" "$MODELS")" typesafe
check "uses the unversioned local System One API root" "$(yq -r ".providers.openjev.baseUrl" "$MODELS")" http://127.0.0.1:8091
check "selects OpenJev model id" "$(yq -r ".providers.openjev.models[0].id" "$MODELS")" openjev-latest
check "enables curated Mnemopi memory" "$(yq -r '.memory.backend' "$CONFIG")" mnemopi
check "uses project-tagged Mnemopi scope" "$(yq -r '.mnemopi.scoping' "$CONFIG")" per-project-tagged
check "recalls memory automatically" "$(yq -r '.mnemopi.autoRecall' "$CONFIG")" true
check "disables automatic memory retention" "$(yq -r '.mnemopi.autoRetain' "$CONFIG")" false
check "caps memory injection" "$(yq -r '.mnemopi.injectionTokenLimit' "$CONFIG")" 1200
check "does not configure ignored skills" "$(yq -r '(.skills.ignoredSkills // []) | length' "$CONFIG")" 0

STALE_AOE="$WORK/stale-aoe.toml"
printf '[plugins."agent-of-empires.github"]\nenabled = true\n[host_hooks]\nbefore_session = ["stale-router"]\nafter_session = ["keep-hook"]\n[session.agent_command_override]\nomp = "stale-omp"\nother = "keep-agent"\n' \
  | chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$DATA" --with-stdin --file "$REPO_ROOT/dot_config/agent-of-empires/modify_config.toml" > "$STALE_AOE"
check "preserves unrelated AoE hooks" "$(yq -p=toml -o=json '.host_hooks.after_session[0]' "$STALE_AOE" | jq -r '.')" keep-hook
check "removes the stale AoE OMP override" "$(yq -p=toml -o=json '.session.agent_command_override | has("omp")' "$STALE_AOE")" false
check "preserves unrelated AoE agent overrides" "$(yq -p=toml -o=json '.session.agent_command_override.other' "$STALE_AOE" | jq -r '.')" keep-agent
check "preserves the configured AoE GitHub plugin" "$(yq -p=toml -o=json '.plugins | has("agent-of-empires.github")' "$STALE_AOE")" true
STALE_ATTENTION="$WORK/stale-attention.toml"
cat <<'EOF' | chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$DATA" --with-stdin --file "$REPO_ROOT/dot_config/agent-of-empires/modify_config.toml" > "$STALE_ATTENTION"
[plugins."athal7.attention"]
enabled = false
source = "gh:other/stale"
[plugins."athal7.attention".grant]
capabilities = ["net", "notifications"]
manifest_hash = "sha256:stale"
EOF
EXPECTED_ATTENTION_HASH="sha256:6cabc6e86f83b879""b7b00e1f6b6b6e4b""6872f3d534691393""a631e4d662d0e884"
check "overrides stale live AoE Attention grant" "$(yq -p=toml -o=json '.' "$STALE_ATTENTION" | jq -r --arg hash "$EXPECTED_ATTENTION_HASH" '.plugins["athal7.attention"] | .enabled == true and .source == "gh:athal7/attention" and .grant.capabilities == ["runtime.worker", "session.read", "net"] and .grant.manifest_hash == $hash')" true
if bash -n "$PLUGIN_INSTALL"; then
  plugin_install_valid=true
else
  plugin_install_valid=false
fi
check "renders the configured AoE plugin installer" "$plugin_install_valid" true
check "installs the configured AoE GitHub plugin" "$(grep -Fxc '  if ! aoe plugin install gh:agent-of-empires/plugin-github --yes < /dev/null; then' "$PLUGIN_INSTALL")" 1
check "installs the configured AoE Attention plugin" "$(grep -Fxc '  if ! aoe plugin install gh:athal7/attention --yes < /dev/null; then' "$PLUGIN_INSTALL")" 1
check "omits the retired CQ MCP server" "$(jq '.mcpServers | has("cq")' "$MCP")" false
check "keeps Context7 disabled by default" "$(jq '[.mcpServers.context7.enabled, .mcpServers.context7.disabled] == [false, true]' "$MCP")" true
check "keeps selected OMP MCP servers enabled" "$(jq '.mcpServers["codebase-memory"].enabled != false and .mcpServers.runlayer.enabled != false and .mcpServers.slack.enabled != false' "$MCP")" true
check "disables other integration MCP servers by default" "$(jq '[.mcpServers | to_entries[] | select(.key != "context7" and .key != "codebase-memory" and .key != "runlayer" and .key != "slack" and .key != "github") | .value.enabled == false] | all' "$MCP")" true
runlayer_mcp_urls=(
  "bigquery https://bigquery.example.test/mcp"
  "pagerduty https://pagerduty.example.test/mcp"
)
for connector_and_url in "${runlayer_mcp_urls[@]}"; do
  read -r connector url <<< "$connector_and_url"
  check "renders $connector MCP entry" "$(jq --arg connector "$connector" '.mcpServers | has($connector)' "$MCP")" true
  check "renders $connector MCP URL" "$(jq -r --arg connector "$connector" '.mcpServers[$connector].url' "$MCP")" "$url"
done
check "enables the official GitHub MCP by default" "$(jq -r '.mcpServers.github.enabled != false and .mcpServers.github.disabled != true' "$MCP")" true
check "uses the official GitHub MCP endpoint" "$(jq -r '.mcpServers.github.url' "$MCP")" "https://api.githubcopilot.com/mcp/"
check "selects the official GitHub MCP toolsets" "$(jq -r '.mcpServers.github.headers["X-MCP-Toolsets"]' "$MCP")" "context,issues,pull_requests,repos,users,actions"
check "includes review-thread read and resolution tools" "$(jq -r '[.mcpServers.github.includeTools[] | select(. == "pull_request_read" or . == "resolve_review_thread")] | length' "$MCP")" 2
check "includes GitHub MCP in scheduled KB enrichment" "$(jq -r '(.mcpServers | has("github"))' "$KB_ENRICH_MCP")" true
check "removes the two Runlayer GitHub connectors" "$(jq -r '[.mcpServers | has("github-orgs"), has("github-other-orgs")] | any' "$MCP")" false
rendered_runlayer_environment="$(yq -p=toml -o=json '.environment' "$AOE" | jq -r '.[]' | sort | paste -sd ' ' -)"
check "exports configured Runlayer MCP URL variables to AoE sessions" "$rendered_runlayer_environment" "RUNLAYER_BIGQUERY_MCP_URL=https://bigquery.example.test/mcp RUNLAYER_PAGERDUTY_MCP_URL=https://pagerduty.example.test/mcp"
if bash -n "$ZSHENV"; then zshenv_valid=true; else zshenv_valid=false; fi
check "renders a valid shell environment" "$zshenv_valid" true
rendered_runlayer_shell_variables="$(grep '^export RUNLAYER_.*_MCP_URL=' "$ZSHENV" | cut -d= -f1 | sort | paste -sd ' ' -)"
check "exports only configured Runlayer MCP URLs to shell sessions" "$rendered_runlayer_shell_variables" "export RUNLAYER_BIGQUERY_MCP_URL export RUNLAYER_PAGERDUTY_MCP_URL"
configured_mcp_servers="$(yq -r '.mcp_servers[].name' "$REPO_ROOT/.chezmoidata/mcp.yaml" | sort | paste -sd ' ' -)"
check "includes every configured MCP server in the KB overlay" "$(jq -r '.mcpServers | keys | sort | join(" ")' "$KB_ENRICH_MCP")" "$configured_mcp_servers"
check "preserves GitHub tool allowlist in KB enrichment" "$(jq -c '.mcpServers.github.includeTools' "$KB_ENRICH_MCP")" "$(jq -c '.mcpServers.github.includeTools' "$MCP")"
check "preserves GitHub toolset header in KB enrichment" "$(jq -r '.mcpServers.github.headers["X-MCP-Toolsets"]' "$KB_ENRICH_MCP")" "$(jq -r '.mcpServers.github.headers["X-MCP-Toolsets"]' "$MCP")"
check "renders the Calendar MCP URL" "$(jq -r '.mcpServers["gcalendar"].url' "$KB_ENRICH_MCP")" "\${RUNLAYER_GCALENDAR_MCP_URL}"
check "enables every KB enrichment MCP server" "$(jq '[.mcpServers[].enabled] | all(. == true)' "$KB_ENRICH_MCP")" true
LAUNCH_AGENTS="$WORK/agents.yaml"
chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$DATA" --file "$REPO_ROOT/dot_config/launchd-yaml/agents.yaml.tmpl" > "$LAUNCH_AGENTS"
check "removes replaced llama LaunchAgent" "$(yq -o=json ".launchagents" "$LAUNCH_AGENTS" | jq "has(\"llama-server\")")" false
check "runs OpenJev on loopback and the reserved port" "$(yq -r ".launchagents.openjev.EnvironmentVariables | [.OPENJEV_HOST, .OPENJEV_PORT] | join(\":\")" "$LAUNCH_AGENTS")" 127.0.0.1:8091
check "limits OpenJev MLX cache" "$(yq -r ".launchagents.openjev.EnvironmentVariables.OPENJEV_MLX_CACHE_LIMIT_GB" "$LAUNCH_AGENTS")" 4
check "gives daily maintenance the KB scratch MCP overlay" "$(yq -r '.launchagents."aoe-daily-maintenance".EnvironmentVariables.AOE_OMP_PROJECT_MCP_CONFIG' "$LAUNCH_AGENTS")" "\$HOME/.config/omp/agent/kb-enrich-mcp.json"
check "configures Homebridge storage under XDG" "$(yq -r '.launchagents.homebridge.ProgramArguments[2]' "$LAUNCH_AGENTS")" "\$HOME/.config/homebridge"
check "configures Homebridge UI storage under XDG" "$(yq -r '.launchagents.homebridge.EnvironmentVariables.UIX_STORAGE_PATH' "$LAUNCH_AGENTS")" "\$HOME/.config/homebridge"
check "does not set a global daily maintenance cutoff" "$(yq -r '.launchagents."aoe-daily-maintenance".EnvironmentVariables | has("AOE_OMP_MAX_TIME")' "$LAUNCH_AGENTS")" false
check "passes the daily prompt file" "$(yq -r '.launchagents."aoe-daily-maintenance".ProgramArguments[2]' "$LAUNCH_AGENTS")" "\$HOME/.agents/prompts/daily-maintenance.md"

check "runs daily maintenance at the original enrichment time" "$(yq -o=json '.launchagents."aoe-daily-maintenance".StartCalendarInterval' "$LAUNCH_AGENTS" | jq '[.[].Minute] | unique | if . == [0] then 0 else . end')" 0
check "removes superseded scheduled sessions" "$(yq -o=json '.launchagents' "$LAUNCH_AGENTS" | jq 'has("aoe-kb-enrich") or has("aoe-fix-prod-errors") or has("aoe-audit")')" false

mkdir -p "$AGENT_DIR"
cp "$MODELS" "$AGENT_DIR/models.yml"
cp "$CONFIG" "$AGENT_DIR/config.yml"
auto_resume="$(PI_CODING_AGENT_DIR="$AGENT_DIR" omp config get autoResume --json | jq -r '.value')"
check "OMP accepts disabled automatic resume" "$auto_resume" false

printf '\n== summary: %s passed, %s failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
