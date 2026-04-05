#!/usr/bin/env bash
# imessage.sh — send an iMessage to self
# Usage: imessage.sh "message text"
# Finds Apple ID from system defaults rather than hardcoding it

set -euo pipefail

MESSAGE="${1:-}"
if [ -z "$MESSAGE" ]; then
  echo "Usage: imessage.sh 'message'" >&2
  exit 1
fi

# Get Apple ID from system — works for iCloud-signed-in Macs
APPLE_ID=$(defaults read MobileMeAccounts 2>/dev/null | \
  grep -A1 "AccountID" | grep -v "AccountID" | tr -d ' "' | head -1)

if [ -z "$APPLE_ID" ]; then
  # Fallback: try to get from iCloud preferences
  APPLE_ID=$(defaults read ~/Library/Preferences/MobileMeAccounts 2>/dev/null | \
    grep "AccountID" | awk -F'"' '{print $2}' | head -1)
fi

if [ -z "$APPLE_ID" ]; then
  echo "Could not determine Apple ID — set IMESSAGE_TARGET env var to override" >&2
  APPLE_ID="${IMESSAGE_TARGET:-}"
  [ -z "$APPLE_ID" ] && exit 1
fi

# Send via Shortcuts if available (more reliable than scripting Messages.app)
if command -v shortcuts &>/dev/null; then
  echo "$MESSAGE" | shortcuts run "Send iMessage to Self" --input-path /dev/stdin 2>/dev/null && exit 0
fi

# Fallback: AppleScript
osascript - "$APPLE_ID" "$MESSAGE" <<'EOF'
on run {recipient, msg}
  tell application "Messages"
    set targetService to first service whose service type = iMessage
    set targetBuddy to buddy recipient of targetService
    send msg to targetBuddy
  end tell
end run
EOF
