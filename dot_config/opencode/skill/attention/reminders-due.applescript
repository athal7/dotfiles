-- Returns overdue and due-today reminders across all lists
-- Usage: osascript reminders-due.applescript
tell application "Reminders"
  set rightNow to current date
  set tomorrow to rightNow + (24 * hours)
  set dueItems to {}
  repeat with lst in every list
    set overdueItems to (every reminder of lst whose completed is false and due date < rightNow)
    set todayItems to (every reminder of lst whose completed is false and due date >= rightNow and due date < tomorrow)
    repeat with r in overdueItems
      set end of dueItems to ("OVERDUE: " & name of r & " [" & name of lst & "]")
    end repeat
    repeat with r in todayItems
      set end of dueItems to ("TODAY: " & name of r & " [" & name of lst & "]")
    end repeat
  end repeat
  return dueItems
end tell
