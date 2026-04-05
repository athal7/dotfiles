#!/usr/bin/env bash
# post-meeting.sh — extract action items from recently ended meetings
# Runs hourly via LaunchAgent
# For each meeting that ended in the last 2 hours with no processed marker:
#   1. Get transcript via minutes CLI
#   2. Extract action items via OpenCode session
#   3. Add each as a HIGH priority Reminder
#   4. Send iMessage summary to self

set -euo pipefail

PROCESSED_LOG="${HOME}/.local/share/ea/processed-meetings.txt"
OPENCODE_API="http://localhost:4096"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$(dirname "$PROCESSED_LOG")"
touch "$PROCESSED_LOG"

# Find meetings that ended in the last 2 hours
NOW=$(date +%s)
TWO_HOURS_AGO=$((NOW - 7200))

# Get recent meetings from minutes
RECENT=$(minutes list --json 2>/dev/null || echo "[]")
if [ "$RECENT" = "[]" ] || [ -z "$RECENT" ]; then
  exit 0
fi

# Filter to meetings that ended in the window and haven't been processed
echo "$RECENT" | jq -c '.[]' | while read -r meeting; do
  MEETING_ID=$(echo "$meeting" | jq -r '.id')
  MEETING_TITLE=$(echo "$meeting" | jq -r '.title // "Meeting"')
  MEETING_END=$(echo "$meeting" | jq -r '.endTime // empty')

  # Skip if no end time or already processed
  [ -z "$MEETING_END" ] && continue
  grep -qF "$MEETING_ID" "$PROCESSED_LOG" && continue

  # Check if meeting ended in the last 2 hours
  END_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${MEETING_END%.*}" "+%s" 2>/dev/null || echo 0)
  [ "$END_EPOCH" -lt "$TWO_HOURS_AGO" ] && continue
  [ "$END_EPOCH" -gt "$NOW" ] && continue

  # Get transcript
  TRANSCRIPT=$(minutes transcript "$MEETING_ID" 2>/dev/null || echo "")
  [ -z "$TRANSCRIPT" ] && continue

    # Extract action items via OpenCode session
  # Ask for title, optional due date (ISO or null), and list (Work/Personal/Inbox)
  PROMPT="Extract action items from this meeting transcript that are assigned to or agreed upon by me. Return ONLY a JSON array of objects with these fields:
- title: string (the task)
- due: string or null (ISO date if a deadline was mentioned, otherwise null)
- list: string (\"Work\" for work tasks, \"Personal\" for personal tasks, \"Inbox\" if unclear)

Do not assign priority — that is for the human to decide. If there are no clear action items, return [].

Transcript:

${TRANSCRIPT}"

  RESPONSE=$(curl -s -X POST "${OPENCODE_API}/session" \
    -H "Content-Type: application/json" \
    -d '{}' 2>/dev/null)
  SESSION_ID=$(echo "$RESPONSE" | jq -r '.id // empty')

  if [ -n "$SESSION_ID" ]; then
    curl -s -X POST "${OPENCODE_API}/session/${SESSION_ID}/message" \
      -H "Content-Type: application/json" \
      -d "{\"parts\": [{\"type\": \"text\", \"text\": $(echo "$PROMPT" | jq -Rs .)}]}" \
      >/dev/null 2>&1

    # Poll for completion — check status instead of sleeping blindly
    for _ in $(seq 1 24); do
      sleep 5
      STATUS=$(curl -s "${OPENCODE_API}/session/status" 2>/dev/null | \
        jq -r --arg id "$SESSION_ID" '.[$id].type // "unknown"')
      [ "$STATUS" = "idle" ] && break
    done

    # Get the response text
    ACTION_ITEMS_JSON=$(curl -s "${OPENCODE_API}/session/${SESSION_ID}" 2>/dev/null | \
      jq -r '[.messages[-1].parts[] | select(.type=="text") | .text] | last // "[]"')

    # Parse and add each action item as a Reminder — no priority set
    COUNT=0
    while IFS= read -r item_json; do
      TITLE=$(echo "$item_json" | jq -r '.title // empty')
      DUE=$(echo "$item_json" | jq -r '.due // empty')
      LIST=$(echo "$item_json" | jq -r '.list // "Inbox"')

      [ -z "$TITLE" ] && continue

      CMD="remindctl add \"$LIST\" --title \"$TITLE\""
      [ -n "$DUE" ] && CMD="$CMD --due-date \"$DUE\""
      eval "$CMD" 2>/dev/null && COUNT=$((COUNT + 1))
    done < <(echo "$ACTION_ITEMS_JSON" | jq -c '.[]' 2>/dev/null)

    # Send iMessage summary if there were action items
    if [ "$COUNT" -gt 0 ]; then
      MSG="📋 ${MEETING_TITLE}: ${COUNT} action item$([ "$COUNT" -gt 1 ] && echo 's' || echo '') → Reminders (no priority set)"
      bash "${SCRIPT_DIR}/imessage.sh" "$MSG"
    fi
  fi

  # Mark as processed
  echo "$MEETING_ID" >> "$PROCESSED_LOG"
done
