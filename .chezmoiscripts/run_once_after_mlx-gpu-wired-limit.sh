#!/bin/bash
# Raise the macOS GPU wired-memory ceiling (iogpu.wired_limit_mb) for
# capacity/headroom only. Default is ~75% of RAM (~36GB on this 48GB
# machine); bump to 40GB, leaving 8GB of headroom, as a cushion against
# ordinary GPU OOM when running local models. This is NOT a fix for the
# IOGPUFamily residency-race kernel panic (IOGPUMemory.cpp:550) seen with
# mlx-qwen-server — those mitigations live in the launchd agent config
# (dot_config/launchd-yaml/agents.yaml: wired-limit no-op shim, reduced
# concurrency) — this script just raises the size ceiling.
set -euo pipefail

SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_LINE="iogpu.wired_limit_mb=40960"

if ! grep -qxF "$SYSCTL_LINE" "$SYSCTL_CONF" 2>/dev/null; then
  echo "$SYSCTL_LINE" | sudo tee -a "$SYSCTL_CONF" >/dev/null
fi
sudo chown root:wheel "$SYSCTL_CONF"
sudo chmod 644 "$SYSCTL_CONF"

CURRENT_VALUE="$(sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo "")"
if [ "$CURRENT_VALUE" != "40960" ]; then
  sudo sysctl iogpu.wired_limit_mb=40960
fi
