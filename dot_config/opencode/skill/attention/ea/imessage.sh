#!/usr/bin/env bash
# notify.sh — send a notification to self
# Primary: native macOS display notification (works reliably from LaunchAgents)
# Fallback: iMessage via Shortcuts if configured
# Usage: imessage.sh "message text"

set -euo pipefail

MESSAGE="${1:-}"
if [ -z "$MESSAGE" ]; then
  echo "Usage: imessage.sh 'message'" >&2
  exit 1
fi

# Primary: native macOS notification — works reliably from user-level LaunchAgents
if osascript -e "display notification \"${MESSAGE}\" with title \"EA\"" 2>/dev/null; then
  exit 0
fi

# Fallback: iMessage via Shortcuts (requires "Send iMessage to Self" Shortcut)
APPLE_ID=$(defaults read MobileMeAccounts 2>/dev/null | \
  grep -A1 "AccountID" | grep -v "AccountID" | tr -d ' "' | head -1)
if [ -n "$APPLE_ID" ] && command -v shortcuts &>/dev/null; then
  echo "$MESSAGE" | shortcuts run "Send iMessage to Self" --input-path /dev/stdin 2>/dev/null || true
fi
