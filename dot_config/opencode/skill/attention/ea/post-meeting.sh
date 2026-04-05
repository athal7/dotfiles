#!/usr/bin/env bash
# post-meeting.sh — surface action items after meetings end
# Runs hourly via LaunchAgent
# Uses minutes actions to find newly extracted action items since last run,
# adds any assigned to you to Reminders, and sends a notification summary.
# Requires minutes summarization engine = "agent" to produce structured action items.

set -euo pipefail

PROCESSED_LOG="${HOME}/.local/share/ea/processed-meetings.txt"
MEETINGS_DIR="${HOME}/meetings"
MY_NAME="Andrew Thal"

mkdir -p "$(dirname "$PROCESSED_LOG")"
touch "$PROCESSED_LOG"

# Find meeting files modified since the processed log was last updated (i.e. recently processed by minutes)
while IFS= read -r meeting_file; do
  SLUG=$(basename "$meeting_file" .md)

  # Skip if already processed
  grep -qF "$SLUG" "$PROCESSED_LOG" && continue

  # Extract title from frontmatter
  TITLE=$(grep "^title:" "$meeting_file" 2>/dev/null | sed 's/^title: *//' | head -1)
  [ -z "$TITLE" ] && TITLE="$SLUG"

  # Extract action items assigned to me from frontmatter
  # minutes uses YAML array: - assignee: "Name"\n   task: "..."\n   status: open
  COUNT=0
  IN_ITEM=0
  ASSIGNEE=""
  TASK=""
  DUE=""

  while IFS= read -r line; do
    if echo "$line" | grep -q "^action_items:"; then
      IN_ITEM=1
      continue
    fi
    # End of action_items section
    if [ "$IN_ITEM" = "1" ] && echo "$line" | grep -qE "^[a-z]"; then
      IN_ITEM=0
    fi
    if [ "$IN_ITEM" = "1" ]; then
      if echo "$line" | grep -q "assignee:"; then
        ASSIGNEE=$(echo "$line" | sed 's/.*assignee: *//' | tr -d '"')
      elif echo "$line" | grep -q "task:"; then
        TASK=$(echo "$line" | sed 's/.*task: *//' | tr -d '"')
      elif echo "$line" | grep -q "due:"; then
        DUE=$(echo "$line" | sed 's/.*due: *//' | tr -d '"')
      elif echo "$line" | grep -q "status:"; then
        STATUS=$(echo "$line" | sed 's/.*status: *//' | tr -d '"')
        # Save item if assigned to me and open
        if echo "$ASSIGNEE" | grep -qi "$MY_NAME" && [ "${STATUS:-open}" = "open" ] && [ -n "$TASK" ]; then
          CMD="remindctl add \"Work\" --title \"$TASK\""
          [ -n "$DUE" ] && CMD="$CMD --due-date \"$DUE\""
          eval "$CMD" 2>/dev/null && COUNT=$((COUNT + 1))
        fi
        ASSIGNEE=""
        TASK=""
        DUE=""
      fi
    fi
  done < "$meeting_file"

  # Notify if action items were found
  if [ "$COUNT" -gt 0 ]; then
    osascript -e "display notification \"${COUNT} action item$([ "$COUNT" -gt 1 ] && echo 's' || echo '') added to Reminders\" with title \"${TITLE}\"" 2>/dev/null || true
  fi

  echo "$SLUG" >> "$PROCESSED_LOG"

done < <(find "$MEETINGS_DIR" -name "*.md" -newer "$PROCESSED_LOG" -not -path "*/memos/*" 2>/dev/null)
