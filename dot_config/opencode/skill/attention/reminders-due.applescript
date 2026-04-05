-- Returns reminders that need attention:
--   BLOCKED:  flagged items (flagged = blocked on something external)
--   OVERDUE:  past due date
--   TODAY:    due today
--   HIGH:     no due date, priority 1 (high)
--   MEDIUM:   no due date, priority 2 (medium) — surface when spoons allow
-- Usage: osascript reminders-due.applescript
tell application "Reminders"
  set rightNow to current date
  set tomorrow to rightNow + (24 * hours)
  set result to {}
  repeat with lst in every list
    set allPending to (every reminder of lst whose completed is false)
    repeat with r in allPending
      set rName to name of r
      set rList to name of lst
      set rFlagged to flagged of r
      set rPriority to priority of r
      -- due date may not exist — check with a try block
      set hasDueDate to false
      set rDue to missing value
      try
        set rDue to due date of r
        set hasDueDate to true
      end try

      if rFlagged then
        set end of result to "BLOCKED: " & rName & " [" & rList & "]"
      else if hasDueDate then
        if rDue < rightNow then
          set end of result to "OVERDUE: " & rName & " [" & rList & "]"
        else if rDue < tomorrow then
          set end of result to "TODAY: " & rName & " [" & rList & "]"
        end if
      else if rPriority is 1 then
        set end of result to "HIGH: " & rName & " [" & rList & "]"
      else if rPriority is 2 then
        set end of result to "MEDIUM: " & rName & " [" & rList & "]"
      end if
    end repeat
  end repeat
  return result
end tell
