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
check "uses the live custom OMP status-line preset" "$(yq -r '.statusLine.preset' "$CONFIG")" custom
check "shows model, prewalk mode, and cost in the OMP status line" "$(yq -r '[.statusLine.leftSegments[], .statusLine.rightSegments[]] | join(" ")' "$CONFIG")" "model mode cost"
check "preserves tight OMP TUI layout" "$(yq -r '.tui.tight' "$CONFIG")" true
check "preserves unexpected stop detection override" "$(yq -r '.features.unexpectedStopDetection' "$CONFIG")" smart
check "renders the AoE-managed OMP hook directory" "$(yq -p=toml -o=json '.environment' "$AOE" | jq -r '.[] | select(startswith("PI_CODING_AGENT_DIR="))')" "PI_CODING_AGENT_DIR=$HOME/.config/omp/agent"
check "uses the configured AoE OMP environment hook" "$(yq -p=toml -o=json '.host_hooks.before_session[0]' "$AOE" | jq -r '.')" "if [ \"\$AOE_TOOL\" = omp ]; then \"\$HOME/.local/bin/aoe-omp-environment\"; fi"
check "does not put AoE runtime state in config.toml" "$(yq -p=toml -o=json 'has("app_state")' "$AOE")" false
check "does not retain AoE live agent overrides" "$(yq -p=toml -o=json '.session | has("agent_command_override")' "$AOE")" false
check "preserves OpenAI Codex code mode override" "$(yq -r '.providers.openai-codex.codeMode' "$CONFIG")" auto
check "does not configure a judge model role" "$(yq -r '.modelRoles | has("judge")' "$CONFIG")" false
check "does not configure a local OpenJev provider" "$(yq -r 'has("openjev")' "$MODELS")" false
check "enables curated Mnemopi memory" "$(yq -r '.memory.backend' "$CONFIG")" mnemopi
check "uses project-tagged Mnemopi scope" "$(yq -r '.mnemopi.scoping' "$CONFIG")" per-project-tagged
check "recalls memory automatically" "$(yq -r '.mnemopi.autoRecall' "$CONFIG")" true
check "disables automatic memory retention" "$(yq -r '.mnemopi.autoRetain' "$CONFIG")" false
check "caps memory injection" "$(yq -r '.mnemopi.injectionTokenLimit' "$CONFIG")" 1200
check "does not configure ignored skills" "$(yq -r '(.skills.ignoredSkills // []) | length' "$CONFIG")" 0

if bash -n "$PLUGIN_INSTALL"; then
  plugin_install_valid=true
else
  plugin_install_valid=false
fi
check "renders the configured AoE plugin installer" "$plugin_install_valid" true
check "preserves the configured AoE default agent" "$(yq -p=toml -o=json '.' "$AOE" | jq -r '.acp.default_agent')" omp
check "enables AoE plugin auto-updates" "$(yq -p=toml -o=json '.' "$AOE" | jq -r '.updates.auto_update_plugins')" true
check "grants the reviewed GitHub plugin capability set" "$(yq -p=toml -o=json '.' "$AOE" | jq -r '.plugins["agent-of-empires.github"].grant.capabilities | join(" ")')" "net runtime.worker session.read notifications browser_open"
check "pins the updated GitHub plugin manifest hash" "$(yq -p=toml -o=json '.' "$AOE" | jq -r '.plugins["agent-of-empires.github"].grant.manifest_hash')" "$(printf 'sha256:%s%s%s%s' '78c76fd828003b3c' '91f57674295713ca' 'c96690a156521a05' 'd83f890ed47e77ac')"
check "preserves the Attention plugin grants" "$(yq -p=toml -o=json '.' "$AOE" | jq -r '.plugins["athal7.attention"].grant.capabilities | join(" ")')" "runtime.worker session.read session.create session.unattended net"
check "reloads the supervised AoE daemon after plugin sync" "$(grep -Fxc "if [ \"\$plugin_synced\" = true ] && aoe serve --status > /dev/null 2>&1; then" "$PLUGIN_INSTALL")" 1
check "restarts AoE Serve through its LaunchAgent" "$(grep -Fxc "    launchctl kickstart -k \"\$serve_job\" ||" "$PLUGIN_INSTALL")" 1

MOCK_HOME="$WORK/mock-home"
mkdir -p "$MOCK_HOME/.config/agent-of-empires/plugins/agent-of-empires.github" "$MOCK_HOME/.config/agent-of-empires/plugins/athal7.attention"
MOCK_BIN="$MOCK_HOME/.local/share/mise/shims"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/aoe" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "serve --status") [ "${AOE_RUNNING:-false}" = true ] ;;
  "plugin update "*|"plugin install "*) exit 0 ;;
  *) exit 1 ;;
esac
EOF
cat > "$MOCK_BIN/launchctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$LAUNCHCTL_LOG"
case "$1" in
  print) [ "${AOE_LAUNCHD:-false}" = true ] ;;
  kickstart) exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$MOCK_BIN/aoe" "$MOCK_BIN/launchctl"
LAUNCHCTL_LOG="$WORK/launchctl.log"
: > "$LAUNCHCTL_LOG"
PATH="$MOCK_BIN:$PATH" HOME="$MOCK_HOME" LAUNCHCTL_LOG="$LAUNCHCTL_LOG" \
  AOE_RUNNING=false AOE_LAUNCHD=true bash "$PLUGIN_INSTALL"
check "does not restart AoE when no daemon is running" "$(grep -c '^kickstart -k ' "$LAUNCHCTL_LOG" || true)" 0
: > "$LAUNCHCTL_LOG"
PATH="$MOCK_BIN:$PATH" HOME="$MOCK_HOME" LAUNCHCTL_LOG="$LAUNCHCTL_LOG" \
  AOE_RUNNING=true AOE_LAUNCHD=true bash "$PLUGIN_INSTALL"
check "restarts AoE once after successful plugin sync" "$(grep -c '^kickstart -k ' "$LAUNCHCTL_LOG" || true)" 1
check "auto-approves changed GitHub plugin capabilities" "$(grep -Fxc '  if aoe plugin update agent-of-empires.github --yes < /dev/null; then' "$PLUGIN_INSTALL")" 1
check "auto-approves changed Attention plugin capabilities" "$(grep -Fxc '  if aoe plugin update athal7.attention --yes < /dev/null; then' "$PLUGIN_INSTALL")" 1
check "omits the retired CQ MCP server" "$(jq '.mcpServers | has("cq")' "$MCP")" false
check "enables Context7 by default" "$(jq '.mcpServers.context7.enabled == true' "$MCP")" true
check "keeps selected OMP MCP servers enabled" "$(jq '.mcpServers["codebase-memory"].enabled == true and .mcpServers.runlayer.enabled == true and .mcpServers.slack.enabled == true' "$MCP")" true
check "enables other integration MCP servers by default" "$(jq '[.mcpServers | to_entries[] | select(.key != "context7" and .key != "codebase-memory" and .key != "runlayer" and .key != "slack" and .key != "github") | .value.enabled == true] | all' "$MCP")" true
runlayer_mcp_urls=(
  "bigquery https://bigquery.example.test/mcp"
  "pagerduty https://pagerduty.example.test/mcp"
)
for connector_and_url in "${runlayer_mcp_urls[@]}"; do
  read -r connector url <<< "$connector_and_url"
  check "renders $connector MCP entry" "$(jq --arg connector "$connector" '.mcpServers | has($connector)' "$MCP")" true
  check "renders $connector MCP URL" "$(jq -r --arg connector "$connector" '.mcpServers[$connector].url' "$MCP")" "$url"
done
check "enables the official GitHub MCP by default" "$(jq '.mcpServers.github.enabled == true' "$MCP")" true
check "uses the official GitHub MCP endpoint" "$(jq -r '.mcpServers.github.url' "$MCP")" "https://api.githubcopilot.com/mcp/"
check "selects the official GitHub MCP toolsets" "$(jq -r '.mcpServers.github.headers["X-MCP-Toolsets"]' "$MCP")" "context,issues,pull_requests,repos,users,actions"
expected_github_authorization="Bearer \${GITHUB_TOKEN}"
check "defers GitHub token expansion to OMP startup" "$(jq -r '.mcpServers.github.headers.Authorization' "$MCP")" "$expected_github_authorization"
check "preserves GitHub token expansion in KB enrichment" "$(jq -r '.mcpServers.github.headers.Authorization' "$KB_ENRICH_MCP")" "$expected_github_authorization"
check "includes GitHub MCP in scheduled KB enrichment" "$(jq -r '(.mcpServers | has("github"))' "$KB_ENRICH_MCP")" true
check "removes the two Runlayer GitHub connectors" "$(jq -r '[.mcpServers | has("github-orgs"), has("github-other-orgs")] | any' "$MCP")" false
rendered_runlayer_environment="$(yq -p=toml -o=json '.environment' "$AOE" | jq -r '.[]' | sort | paste -sd ' ' -)"
check "exports configured Runlayer URLs and the OMP agent directory to AoE sessions" "$rendered_runlayer_environment" "PI_CODING_AGENT_DIR=$HOME/.config/omp/agent RUNLAYER_BIGQUERY_MCP_URL=https://bigquery.example.test/mcp RUNLAYER_PAGERDUTY_MCP_URL=https://pagerduty.example.test/mcp"
if bash -n "$ZSHENV"; then zshenv_valid=true; else zshenv_valid=false; fi
check "renders a valid shell environment" "$zshenv_valid" true
rendered_runlayer_shell_variables="$(grep '^export RUNLAYER_.*_MCP_URL=' "$ZSHENV" | cut -d= -f1 | sort | paste -sd ' ' -)"
check "exports only configured Runlayer MCP URLs to shell sessions" "$rendered_runlayer_shell_variables" "export RUNLAYER_BIGQUERY_MCP_URL export RUNLAYER_PAGERDUTY_MCP_URL"
configured_mcp_servers="$(yq -r '.mcp_servers[].name' "$REPO_ROOT/.chezmoidata/mcp.yaml" | sort | paste -sd ' ' -)"
check "includes every configured MCP server in the KB overlay" "$(jq -r '.mcpServers | keys | sort | join(" ")' "$KB_ENRICH_MCP")" "$configured_mcp_servers"
check "preserves GitHub toolset header in KB enrichment" "$(jq -r '.mcpServers.github.headers["X-MCP-Toolsets"]' "$KB_ENRICH_MCP")" "$(jq -r '.mcpServers.github.headers["X-MCP-Toolsets"]' "$MCP")"
check "renders the Calendar MCP URL" "$(jq -r '.mcpServers["gcalendar"].url' "$KB_ENRICH_MCP")" "\${RUNLAYER_GCALENDAR_MCP_URL}"
check "enables every KB enrichment MCP server" "$(jq '[.mcpServers[].enabled] | all(. == true)' "$KB_ENRICH_MCP")" true
LAUNCH_AGENTS="$WORK/agents.yaml"
chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$DATA" --file "$REPO_ROOT/dot_config/launchd-yaml/agents.yaml.tmpl" > "$LAUNCH_AGENTS"
check "removes replaced llama LaunchAgent" "$(yq -o=json ".launchagents" "$LAUNCH_AGENTS" | jq "has(\"llama-server\")")" false
check "does not run the OpenJev memory-intensive local judge" "$(yq -o=json ".launchagents" "$LAUNCH_AGENTS" | jq "has(\"openjev\")")" false
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
