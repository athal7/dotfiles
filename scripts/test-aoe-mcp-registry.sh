#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aoe_rendered="$(mktemp "${TMPDIR:-/tmp}/aoe-mcp-registry.XXXXXX")"
omp_rendered="$(mktemp "${TMPDIR:-/tmp}/omp-mcp-registry.XXXXXX")"
kb_rendered="$(mktemp "${TMPDIR:-/tmp}/kb-mcp-registry.XXXXXX")"
config_rendered="$(mktemp "${TMPDIR:-/tmp}/omp-config.XXXXXX")"
local_overlay="$(mktemp "${TMPDIR:-/tmp}/local-example.XXXXXX.yaml")"
cp "$REPO_ROOT/local.yaml.example" "$local_overlay"
trap 'rm -f "$aoe_rendered" "$omp_rendered" "$kb_rendered" "$config_rendered" "$local_overlay"' EXIT INT TERM

chezmoi cat -S "$REPO_ROOT" ~/.config/agent-of-empires/mcp.json >"$aoe_rendered"
jq -e '
  .mcpServers.linear == null and
  .mcpServers.spacelift == null and
  .mcpServers.context7 != null and
  .mcpServers.github != null and
  .mcpServers["codebase-memory"] != null and
  .mcpServers["firefox-devtools"] != null
' "$aoe_rendered" >/dev/null

chezmoi cat -S "$REPO_ROOT" ~/.config/omp/agent/mcp.json >"$omp_rendered"
jq -e '
  .mcpServers.linear.enabled == true and
  .mcpServers.spacelift.enabled == true and
  .mcpServers.spacelift.transport == "http" and
  .mcpServers.spacelift.url == "${SPACELIFT_MCP_URL}"
' "$omp_rendered" >/dev/null
chezmoi cat -S "$REPO_ROOT" ~/.config/omp/agent/kb-enrich-mcp.json >"$kb_rendered"
jq -e '.mcpServers.spacelift == null' "$kb_rendered" >/dev/null
chezmoi execute-template -S "$REPO_ROOT" --override-data-file "$local_overlay" < "$REPO_ROOT/dot_config/omp/agent/config.yml.tmpl" >"$config_rendered"
grep -Fx '    mcp__spacelift_mutate: prompt' "$config_rendered" >/dev/null
grep -Fx '    mcp__spacelift_intent: prompt' "$config_rendered" >/dev/null
printf 'AoE ACP excludes OAuth-only servers; OMP keeps Spacelift and prompts for writes.\n'
