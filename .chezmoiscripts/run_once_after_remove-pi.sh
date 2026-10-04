#!/bin/bash
set -euo pipefail

launcher="$HOME/.local/bin/pi"
if [ ! -f "$launcher" ] || ! grep -Fq 'OMP uses PI_* to relocate its own config' "$launcher"; then
  exit 0
fi

pi_tool="npm:@earendil-works/pi-coding-agent"
permission_package="@gotgenes/pi-permission-system"
npm_root="$HOME/.pi/agent/npm"
settings="$HOME/.pi/agent/settings.json"

if [ -f "$npm_root/package.json" ] && jq -e ".dependencies | has(\"$permission_package\")" "$npm_root/package.json" >/dev/null; then
  npm uninstall --prefix "$npm_root" --ignore-scripts --no-audit --no-fund "$permission_package"
fi

rm -f \
  "$settings" \
  "$HOME/.pi/agent/models.json" \
  "$HOME/.pi/agent/mcp.json" \
  "$HOME/.pi/agent/extensions/pi-permission-system/config.json"

while IFS= read -r version; do
  [ -n "$version" ] || continue
  mise uninstall --yes "$pi_tool@$version"
done < <(mise ls --installed --json "$pi_tool" | jq -r '.[].version')
mise reshim
rm -f "$launcher"
