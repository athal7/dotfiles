#!/usr/bin/env bash
# weekly-digest.sh — Sunday evening schedule awareness digest
# Sends one iMessage with next week's picture:
#   - Meeting density
#   - Open HIGH/OVERDUE reminders
#   - In Progress Linear issues
#   - Open calendar gaps (for family-scheduler)
# Soft suggestions only — nothing is auto-added

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINEAR_API="https://api.linear.app/graphql"

# --- Calendar density (next week, Mon-Fri) ---
CALENDAR_SUMMARY=$(osascript - <<'EOF'
tell application "Calendar"
  set monday to current date
  -- Find next Monday
  repeat until weekday of monday is Monday
    set monday to monday + (1 * days)
  end repeat
  set startOfDay to monday - (time of monday)
  set friday to startOfDay + (4 * days) + (23 * hours) + (59 * minutes)

  set totalMeetings to 0
  set totalHours to 0
  set denseDay to ""
  set maxDayCount to 0

  repeat with offset from 0 to 4
    set dayStart to startOfDay + (offset * days)
    set dayEnd to dayStart + (23 * hours) + (59 * minutes)
    set dayCount to 0
    set dayMins to 0
    repeat with cal in every calendar
      set evts to (every event of cal whose start date >= dayStart and start date <= dayEnd and allday event is false and status is not cancelled)
      repeat with evt in evts
        if notes of evt is missing value or notes of evt does not contain "EA transition block" then
          set totalMeetings to totalMeetings + 1
          set dayCount to dayCount + 1
          set evtMins to round ((end date of evt) - (start date of evt)) / 60
          set totalHours to totalHours + evtMins
        end if
      end repeat
    end repeat
    if dayCount > maxDayCount then
      set maxDayCount to dayCount
      set denseDay to (weekday of dayStart as string)
    end if
  end repeat

  set totalHours to round (totalHours / 60)
  return totalMeetings & " meetings, ~" & totalHours & "h — busiest: " & denseDay
end tell
EOF
)

# --- Open HIGH + OVERDUE reminders ---
REMINDERS=$(remindctl show --json 2>/dev/null | \
  jq -r '[.[] | select(.completed == false) | select(.priority == 1 or (.dueDate != null and .dueDate < now))] | length' 2>/dev/null || echo "?")

# --- In Progress Linear issues ---
LINEAR_COUNT="?"
if [ -n "${LINEAR_API_KEY:-}" ]; then
  LINEAR_RESPONSE=$(gq "$LINEAR_API" \
    -H "Authorization: $LINEAR_API_KEY" \
    -q '{ viewer { assignedIssues(filter: { state: { type: { eq: "started" } } }) { nodes { id } } } }' 2>/dev/null || echo "{}")
  LINEAR_COUNT=$(echo "$LINEAR_RESPONSE" | jq '.data.viewer.assignedIssues.nodes | length' 2>/dev/null || echo "?")
fi

# --- Open gaps (evenings + weekends) ---
GAPS=$(osascript ~/.config/opencode/skill/family-scheduler/calendar-gaps.applescript 2>/dev/null | \
  grep -c "OPEN:" || echo "?")

# --- Compose message ---
MSG="📅 Next week: ${CALENDAR_SUMMARY}
⚡ ${REMINDERS} high/overdue reminders
🔨 ${LINEAR_COUNT} in-progress Linear issues
🌿 ${GAPS} open gap$([ "$GAPS" != "1" ] && echo 's') for family time

Load attention skill to plan or just see how the week unfolds."

bash "${SCRIPT_DIR}/imessage.sh" "$MSG"
