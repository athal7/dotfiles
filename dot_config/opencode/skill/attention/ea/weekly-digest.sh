#!/usr/bin/env bash
# weekly-digest.sh — Sunday evening personal schedule digest
# Light and personal only — no work context (that can wait until Monday)
# Sends one iMessage with:
#   - Next week's meeting density (just the shape of the week)
#   - Open personal/family reminders
#   - Open calendar gaps for family time
# Soft awareness only — nothing is auto-added

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Calendar density (next week, Mon-Fri) — shape of the week only ---
CALENDAR_SUMMARY=$(osascript - <<'EOF'
tell application "Calendar"
  set nextMonday to current date
  repeat until weekday of nextMonday is Monday
    set nextMonday to nextMonday + (1 * days)
  end repeat
  set startOfDay to nextMonday - (time of nextMonday)

  set totalMeetings to 0
  set totalMins to 0
  set denseDay to ""
  set maxDayCount to 0

  repeat with dayOffset from 0 to 4
    set dayStart to startOfDay + (dayOffset * days)
    set dayEnd to dayStart + (23 * hours) + (59 * minutes)
    set dayCount to 0
    repeat with cal in every calendar
      set evts to (every event of cal whose ¬
        start date >= dayStart and start date <= dayEnd and ¬
        allday event is false and status is not cancelled)
      repeat with evt in evts
        set n to notes of evt
        if n is missing value or (n does not contain "EA transition block" and n does not contain "EA lunch hold") then
          set totalMeetings to totalMeetings + 1
          set dayCount to dayCount + 1
          set totalMins to totalMins + (round (((end date of evt) - (start date of evt)) / 60))
        end if
      end repeat
    end repeat
    if dayCount > maxDayCount then
      set maxDayCount to dayCount
      set denseDay to (weekday of dayStart as string)
    end if
  end repeat

  set totalHours to round (totalMins / 60 as real)
  if denseDay is "" then
    return "quiet week ahead (~" & totalHours & "h of meetings)"
  else
    return totalMeetings & " meetings (~" & totalHours & "h) — busiest: " & denseDay
  end if
end tell
EOF
)

# --- Personal reminders only (not work Linear) ---
# Surface overdue or flagged items from personal lists
PERSONAL_REMINDERS=$(
  { remindctl show --json overdue 2>/dev/null; remindctl show --json today 2>/dev/null; } | \
  jq -rs '[.[] | .[] |
    select(.isCompleted == false) |
    select(.listName != "Work")
  ] | unique_by(.id) | length' 2>/dev/null || echo "?"
)

# --- Open family time gaps next week ---
# Note: calendar-gaps.applescript requires Calendar.app access which works
# interactively but not from LaunchAgent. Skip gracefully if it fails.
GAPS=$(osascript ~/.config/opencode/skill/family-scheduler/calendar-gaps.applescript 2>/dev/null | \
  grep -c "OPEN:" 2>/dev/null || echo "0")

# --- Compose notification — title = week shape, body = personal items ---
TITLE="📅 Next week: ${CALENDAR_SUMMARY}"
BODY_PARTS=()

if [ "$PERSONAL_REMINDERS" != "?" ] && [ "$PERSONAL_REMINDERS" -gt 0 ]; then
  BODY_PARTS+=("⚠️ ${PERSONAL_REMINDERS} personal reminder$([ "$PERSONAL_REMINDERS" != "1" ] && echo 's')")
fi

if [ "$GAPS" != "?" ] && [ "$GAPS" -gt 0 ]; then
  BODY_PARTS+=("🌿 ${GAPS} open slot$([ "$GAPS" != "1" ] && echo 's') for family time")
fi

# Send as a notification — only send if there's something worth noting
if [ "${#BODY_PARTS[@]}" -gt 0 ]; then
  BODY=$(printf ' · %s' "${BODY_PARTS[@]}")
  BODY="${BODY:3}"  # strip leading ' · '
  osascript -e "display notification \"${BODY}\" with title \"EA\" subtitle \"${TITLE}\"" 2>/dev/null || \
    bash "${SCRIPT_DIR}/imessage.sh" "${TITLE} — ${BODY}"
else
  # Just the calendar shape, no noise
  osascript -e "display notification \"${TITLE}\" with title \"EA\"" 2>/dev/null || true
fi
