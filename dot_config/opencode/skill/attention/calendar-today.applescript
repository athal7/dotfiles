-- Returns remaining events today across all calendars
-- Usage: osascript calendar-today.applescript
tell application "Calendar"
  set rightNow to current date
  set startOfDay to rightNow - (time of rightNow)
  set endOfDay to startOfDay + (23 * hours) + (59 * minutes)
  set todayEvents to {}
  repeat with cal in every calendar
    set evts to (every event of cal whose start date >= rightNow and start date <= endOfDay)
    repeat with evt in evts
      set end of todayEvents to (summary of evt & " @ " & (start date of evt as string))
    end repeat
  end repeat
  return todayEvents
end tell
