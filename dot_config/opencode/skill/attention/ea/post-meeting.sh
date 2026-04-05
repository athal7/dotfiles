#!/usr/bin/env bash
# post-meeting.sh — surface action items after meetings end
# Runs hourly via LaunchAgent
# Scans meeting files modified since last run, parses action_items frontmatter,
# adds items assigned to me to Work Reminders, sends a notification summary.
# Requires minutes summarization engine = "agent" to produce structured action items.

set -euo pipefail

PROCESSED_LOG="${HOME}/.local/share/ea/processed-meetings.txt"
MEETINGS_DIR="${HOME}/meetings"
MY_NAME="Andrew Thal"

mkdir -p "$(dirname "$PROCESSED_LOG")"
touch "$PROCESSED_LOG"

# Find meeting files newer than the processed log
while IFS= read -r meeting_file; do
  SLUG=$(basename "$meeting_file" .md)
  grep -qF "$SLUG" "$PROCESSED_LOG" && continue

  # Parse action_items from YAML frontmatter using Python
  ITEMS=$(python3 - "$meeting_file" "$MY_NAME" << 'PYEOF'
import sys, re

meeting_file = sys.argv[1]
my_name = sys.argv[2]

with open(meeting_file) as f:
    content = f.read()

fm_match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if not fm_match:
    sys.exit(0)

fm_text = fm_match.group(1)
ai_match = re.search(r'^action_items:\n((?:  .*\n?)*)', fm_text, re.MULTILINE)
if not ai_match:
    sys.exit(0)

items = []
current = {}
for line in ai_match.group(1).splitlines():
    line = line.strip()
    if line.startswith('- '):
        if current:
            items.append(current)
        current = {}
        line = line[2:]
    if ': ' in line:
        k, v = line.split(': ', 1)
        current[k.strip()] = v.strip()
if current:
    items.append(current)

for item in items:
    assignee = item.get('assignee', '')
    task = item.get('task', '')
    due = item.get('due', '')
    status = item.get('status', 'open')
    if my_name.lower() in assignee.lower() and status == 'open' and task:
        print(f"{task}\t{due}")
PYEOF
  )

  TITLE=$(python3 -c "
import re, sys
m = re.search(r'^title: (.+)$', open('$meeting_file').read(), re.MULTILINE)
print(m.group(1) if m else '$(basename "$meeting_file" .md)')
  " 2>/dev/null || echo "$SLUG")

  COUNT=0
  while IFS=$'\t' read -r task due; do
    [ -z "$task" ] && continue
    if [ -n "$due" ] && [ "$due" != "null" ] && [ "$due" != "none" ]; then
      remindctl add "$task" --list Work --due "$due" 2>/dev/null && COUNT=$((COUNT + 1))
    else
      remindctl add "$task" --list Work 2>/dev/null && COUNT=$((COUNT + 1))
    fi
  done <<< "$ITEMS"

  if [ "$COUNT" -gt 0 ]; then
    osascript -e "display notification \"${COUNT} action item$([ "$COUNT" -gt 1 ] && echo 's' || echo '') → Work Reminders\" with title \"${TITLE}\"" 2>/dev/null || true
  fi

  echo "$SLUG" >> "$PROCESSED_LOG"

done < <(find "$MEETINGS_DIR" -name "*.md" -newer "$PROCESSED_LOG" -not -path "*/memos/*" 2>/dev/null)
