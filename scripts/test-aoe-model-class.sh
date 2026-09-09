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
absent() { if [ ! -e "$1" ]; then ok "$2"; else bad "$2"; fi; }
present() { if [ -e "$1" ]; then ok "$2"; else bad "$2"; fi; }

TEST_HOME="$WORK/home"
TEST_SOURCE="$WORK/source"
TEST_BIN="$WORK/bin"
mkdir -p "$TEST_HOME/.config/chezmoi" "$TEST_HOME/.omp/agent" "$TEST_SOURCE/.chezmoidata" "$TEST_BIN"
cat > "$TEST_HOME/.config/chezmoi/chezmoi.toml" <<EOF
sourceDir = "$TEST_SOURCE"
EOF
cat > "$TEST_SOURCE/.chezmoidata/local.yaml" <<'YAML'
model_class:
  default: cloud/sol
  plan: cloud/sol
  slow: cloud/sol
  smol: cloud/terra
  vision: cloud/terra
  designer: "@vision"
  commit: cloud/terra
  tiny: cloud/terra
  task: cloud/sol
orgs:
  cloudorg:
    model_class:
      default: cloud/org-sol
      plan: cloud/org-sol
      slow: cloud/org-sol
      smol: cloud/org-terra
      vision: cloud/org-terra
      designer: "@vision"
      commit: cloud/org-terra
      tiny: cloud/org-terra
      task: cloud/org-sol
  gguforg:
    model_class:
      default: gguf/test
      plan: gguf/test
      slow: gguf/test
      smol: gguf/test
      task: gguf/test
local_model:
  compaction_keep_recent_tokens: 1234
YAML
cat > "$TEST_SOURCE/.chezmoidata/mcp.yaml" <<'YAML'
mcp_servers:
  - name: context7
    transport: remote
    url: https://example.invalid/context7
  - name: linear
    exclude_for_models: [gguf/test]
    transport: remote
    url: https://example.invalid/linear
  - name: chat
    exclude_for_models: [gguf/test]
    transport: remote
    url: https://example.invalid/chat
YAML
cat > "$TEST_HOME/.omp/agent/mcp.json" <<'JSON'
{
  "mcpServers": {
    "context7": {"url":"https://example.invalid/context7"},
    "linear": {"url":"https://example.invalid/linear","headers":{"Authorization":"Bearer test-token-value"}},
    "chat": {"url":"https://example.invalid/chat","env":{"TOKEN":"test-token-value"}}
  }
}
JSON
cat > "$TEST_BIN/chezmoi-fail" <<'EOF'
#!/usr/bin/env bash
exit 37
EOF
chmod +x "$TEST_BIN/chezmoi-fail"

run_router() {
  (
    cd "$1"
    HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" "$ROUTER"
  )
}

run_router_fail() {
  (
    cd "$1"
    HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" CHEZMOI="$TEST_BIN/chezmoi-fail" "$ROUTER"
  )
}

make_repo() {
  local dir=$1
  local owner=${2:-}
  mkdir -p "$dir"
  git init -q "$dir"
  if [ -n "$owner" ]; then
    git -C "$dir" remote add origin "git@github.com:$owner/modelled.git"
  fi
}

cloud="$WORK/cloud"
make_repo "$cloud" cloudorg

echo "== matching organization with cloud matrix =="
run_router "$cloud" && status=0 || status=$?
check "cloud organization exits zero" "$status" 0
check "writes cloud default role" "$(yq -r '.modelRoles.default' "$cloud/.omp/config.yml")" cloud/org-sol
check "writes cloud designer alias" "$(yq -r '.modelRoles.designer' "$cloud/.omp/config.yml")" @vision
check "omits project compaction for cloud" "$(yq -r '.compaction == null' "$cloud/.omp/config.yml")" true
absent "$cloud/.omp/mcp.json" "cloud organization leaves no MCP reduction"
check "excludes generated state from git" "$(grep -qxF '.omp/' "$cloud/.git/info/exclude" && printf true || printf false)" true

gguf="$WORK/gguf"
make_repo "$gguf" gguforg

echo "== matching organization with GGUF roles =="
run_router "$gguf" && status=0 || status=$?
check "GGUF organization exits zero" "$status" 0
check "writes GGUF default role" "$(yq -r '.modelRoles.default' "$gguf/.omp/config.yml")" gguf/test
check "inherits vision role from global matrix" "$(yq -r '.modelRoles.vision' "$gguf/.omp/config.yml")" cloud/terra
check "uses lower GGUF compaction tail" "$(yq -r '.compaction.keepRecentTokens' "$gguf/.omp/config.yml")" 8192
check "disables derived linear MCP" "$(jq -r '.mcpServers.linear.enabled' "$gguf/.omp/mcp.json")" false
check "disables derived chat MCP" "$(jq -r '.mcpServers.chat.enabled' "$gguf/.omp/mcp.json")" false
check "does not disable context7" "$(jq -r '.mcpServers | has("context7")' "$gguf/.omp/mcp.json")" false
check "does not copy headers" "$(jq -r '.mcpServers.linear | has("headers")' "$gguf/.omp/mcp.json")" false
check "does not copy env" "$(jq -r '.mcpServers.chat | has("env")' "$gguf/.omp/mcp.json")" false
check "contains no token values" "$(cat "$gguf/.omp/config.yml" "$gguf/.omp/mcp.json" | grep -q test-token-value && printf false || printf true)" true
before_config="$WORK/before-config.yml"
before_mcp="$WORK/before-mcp.json"
cp "$gguf/.omp/config.yml" "$before_config"
cp "$gguf/.omp/mcp.json" "$before_mcp"
run_router "$gguf" && status=0 || status=$?
check "idempotent second execution exits zero" "$status" 0
check "idempotent config unchanged" "$(cmp -s "$before_config" "$gguf/.omp/config.yml" && printf true || printf false)" true
check "idempotent MCP unchanged" "$(cmp -s "$before_mcp" "$gguf/.omp/mcp.json" && printf true || printf false)" true

lookup_fail="$WORK/lookup-fail"
make_repo "$lookup_fail" gguforg

echo "== organization lookup failure =="
run_router_fail "$lookup_fail" && status=0 || status=$?
check "lookup failure exits zero" "$status" 0
absent "$lookup_fail/.omp/config.yml" "lookup failure leaves no config"

unknown="$WORK/unknown"
make_repo "$unknown" unknownorg

echo "== unknown organization =="
run_router "$unknown" && status=0 || status=$?
check "unknown organization exits zero" "$status" 0
absent "$unknown/.omp/config.yml" "unknown organization leaves no config"

no_remote="$WORK/no-remote"
make_repo "$no_remote"

echo "== repository without GitHub remote =="
run_router "$no_remote" && status=0 || status=$?
check "repository without remote exits zero" "$status" 0
absent "$no_remote/.omp/config.yml" "repository without remote leaves no config"

mkdir -p "$no_remote/.omp"
cat > "$no_remote/.omp/mcp.json" <<'JSON'
{"mcpServers":{"linear":{"enabled":false}}}
JSON
run_router "$no_remote" && status=0 || status=$?
check "repository without remote legacy cleanup exits zero" "$status" 0
absent "$no_remote/.omp/mcp.json" "repository without remote removes legacy MCP"
scratch="$WORK/scratch"
mkdir -p "$scratch"

echo "== non-repository directory =="
run_router "$scratch" && status=0 || status=$?
check "non-repository directory exits zero" "$status" 0
absent "$scratch/.omp/config.yml" "non-repository directory leaves no config"

legacy="$WORK/legacy"
make_repo "$legacy" unknownorg
mkdir -p "$legacy/.omp"
cat > "$legacy/.omp/config.yml" <<'YAML'
modelRoles:
  default: gguf/legacy
  plan: gguf/legacy
  slow: gguf/legacy
  smol: gguf/legacy
compaction:
  keepRecentTokens: 1234
disabledExtensions:
  - mcp:figma-desktop
  - mcp:firefox-devtools
  - mcp:github
  - mcp:linear
  - mcp:runlayer-atlassian
  - mcp:runlayer-gcalendar
  - mcp:runlayer-gdocs
  - mcp:runlayer-gdrive
  - mcp:runlayer-gmail
  - mcp:runlayer-gsheets
  - mcp:runlayer-self
  - mcp:runlayer-slack
  - mcp:runlayer-zoom
YAML
cat > "$legacy/.omp/mcp.json" <<'JSON'
{"mcpServers":{"linear":{"enabled":false},"chat":{"enabled":false}}}
JSON

echo "== removal of exact legacy router output =="
run_router "$legacy" && status=0 || status=$?
check "legacy cleanup exits zero" "$status" 0
absent "$legacy/.omp/config.yml" "removes exact legacy config"
absent "$legacy/.omp/mcp.json" "removes exact legacy MCP"
historical="$WORK/historical"
make_repo "$historical" unknownorg
mkdir -p "$historical/.omp"
cat > "$historical/.omp/mcp.json" <<'JSON'
{"mcpServers":{"github":{"headers":{"Authorization":"Bearer old-token"},"type":"http","url":"https://api.githubcopilot.com/mcp/","enabled":false},"linear":{"type":"http","url":"https://mcp.linear.app/mcp","enabled":false},"runlayer-atlassian":{"type":"http","url":"${RUNLAYER_ATLASSIAN_MCP_URL}","enabled":false},"runlayer-gcalendar":{"type":"http","url":"${RUNLAYER_GCALENDAR_MCP_URL}","enabled":false},"runlayer-gdocs":{"type":"http","url":"${RUNLAYER_GDOCS_MCP_URL}","enabled":false},"runlayer-gdrive":{"type":"http","url":"${RUNLAYER_GDRIVE_MCP_URL}","enabled":false},"runlayer-gmail":{"type":"http","url":"${RUNLAYER_GMAIL_MCP_URL}","enabled":false},"runlayer-gsheets":{"type":"http","url":"${RUNLAYER_GSHEETS_MCP_URL}","enabled":false},"runlayer-self":{"type":"http","url":"${RUNLAYER_SELF_MCP_URL}","enabled":false},"runlayer-slack":{"type":"http","url":"${RUNLAYER_SLACK_MCP_URL}","enabled":false},"runlayer-zoom":{"type":"http","url":"${RUNLAYER_ZOOM_MCP_URL}","enabled":false}}}
JSON

echo "== removal of historical copied MCP output =="
run_router "$historical" && status=0 || status=$?
check "historical MCP cleanup exits zero" "$status" 0
absent "$historical/.omp/mcp.json" "removes copied historical MCP"

user_owned="$WORK/user-owned"
make_repo "$user_owned" gguforg
mkdir -p "$user_owned/.omp"
cat > "$user_owned/.omp/config.yml" <<'YAML'
modelRoles:
  default: user/model
custom: true
YAML
cat > "$user_owned/.omp/mcp.json" <<'JSON'
{"mcpServers":{"custom":{"enabled":true}}}
JSON

echo "== preservation of user-owned project files =="
run_router "$user_owned" >/"$WORK/user-owned.out" 2>"$WORK/user-owned.err" && status=0 || status=$?
check "user-owned preservation exits zero" "$status" 0
check "preserves user config" "$(yq -r '.custom' "$user_owned/.omp/config.yml")" true
check "preserves user MCP" "$(jq -r '.mcpServers.custom.enabled' "$user_owned/.omp/mcp.json")" true
check "warns for user config" "$(grep -q 'preserving user-owned .omp/config.yml' "$WORK/user-owned.err" && printf true || printf false)" true
check "warns for user MCP" "$(grep -q 'preserving user-owned .omp/mcp.json' "$WORK/user-owned.err" && printf true || printf false)" true
run_router "$user_owned" >/"$WORK/user-owned-second.out" 2>"$WORK/user-owned-second.err" && status=0 || status=$?
check "user-owned second run exits zero" "$status" 0
check "second run preserves user config" "$(yq -r '.custom' "$user_owned/.omp/config.yml")" true
check "second run preserves user MCP" "$(jq -r '.mcpServers.custom.enabled' "$user_owned/.omp/mcp.json")" true
absent "$user_owned/.omp/.aoe-model-class" "user-owned files do not get a marker"

printf '\n== summary: %s passed, %s failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
