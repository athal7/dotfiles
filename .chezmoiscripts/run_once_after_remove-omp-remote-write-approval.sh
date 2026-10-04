#!/bin/sh
set -eu

rm -f \
  "$HOME/.config/omp/agent/hooks/pre/remote-write-approval.ts" \
  "$HOME/.config/omp/agent/hooks/pre/mcp-approval-allows.json" \
  "$HOME/.config/omp/agent/hooks/pre/mcp-remote-servers.json" \
  "$HOME/.config/omp/agent/hooks/pre/mcp-mutating-verbs.json"
