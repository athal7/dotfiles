#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
aoe_rendered="$(mktemp "${TMPDIR:-/tmp}/aoe-mcp-registry.XXXXXX")"
omp_rendered="$(mktemp "${TMPDIR:-/tmp}/omp-mcp-registry.XXXXXX")"
trap 'rm -f "$aoe_rendered" "$omp_rendered"' EXIT INT TERM

chezmoi cat -S "$REPO_ROOT" ~/.config/agent-of-empires/mcp.json >"$aoe_rendered"
jq -e '
  .mcpServers.linear == null and
  .mcpServers.context7 != null and
  .mcpServers.github != null and
  .mcpServers["codebase-memory"] != null and
  .mcpServers["firefox-devtools"] != null
' "$aoe_rendered" >/dev/null

chezmoi cat -S "$REPO_ROOT" ~/.config/omp/agent/mcp.json >"$omp_rendered"
jq -e '.mcpServers.linear.enabled == true' "$omp_rendered" >/dev/null
printf 'AoE ACP excludes OAuth-only Linear; OMP retains it and other supported servers.\n'
