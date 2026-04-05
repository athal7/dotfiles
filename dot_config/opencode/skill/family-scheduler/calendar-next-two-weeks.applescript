-- Returns all calendar events for the next 14 days
-- Shows what's already on the calendar so you can decide if a new event fits
-- Usage: osascript calendar-next-two-weeks.applescript
tell application "Calendar"
  set startDate to current date
  set endDate to startDate + (14 * days)
  set result to {}
  repeat with cal in every calendar
    set evts to (every event of cal whose start date >= startDate and start date <= endDate)
    repeat with evt in evts
      set end of result to ((start date of evt as string) & " | " & summary of evt & " [" & name of cal & "]")
    end repeat
  end repeat
  return result
end tell
