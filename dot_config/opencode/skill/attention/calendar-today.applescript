-- Returns remaining events today and time windows
-- Output includes:
--   NEXT_EVENT: <title> @ <time> (in Xm)
--   GAP: Xm until next event  (or "rest of day free" if none)
--   END_OF_DAY: Xm until end of working day (6pm)
--   EVENT: <title> @ <time>  (one line per remaining event)
-- Usage: osascript calendar-today.applescript
tell application "Calendar"
  set rightNow to current date
  set startOfDay to rightNow - (time of rightNow)
  set endOfDay to startOfDay + (23 * hours) + (59 * minutes)
  set workDayEnd to startOfDay + (18 * hours) -- 6pm

  -- Collect all remaining events today, sorted by start time
  set allEvents to {}
  repeat with cal in every calendar
    set evts to (every event of cal whose start date >= rightNow and start date <= endOfDay)
    repeat with evt in evts
      set end of allEvents to {evtTitle:summary of evt, evtStart:start date of evt}
    end repeat
  end repeat

  -- Sort by start time (bubble sort — small lists)
  set n to count of allEvents
  repeat with i from 1 to n - 1
    repeat with j from 1 to n - i
      if evtStart of item j of allEvents > evtStart of item (j + 1) of allEvents then
        set tmp to item j of allEvents
        set item j of allEvents to item (j + 1) of allEvents
        set item (j + 1) of allEvents to tmp
      end if
    end repeat
  end repeat

  set output to {}

  -- Time until next event
  if n > 0 then
    set nextEvt to item 1 of allEvents
    set minsToNext to round ((evtStart of nextEvt) - rightNow) / 60
    set end of output to "NEXT_EVENT: " & (evtTitle of nextEvt) & " @ " & (evtStart of nextEvt as string) & " (in " & minsToNext & "m)"
    set end of output to "GAP: " & minsToNext & "m until next event"
  else
    set end of output to "GAP: rest of day free"
  end if

  -- Time until end of working day
  if rightNow < workDayEnd then
    set minsToEnd to round (workDayEnd - rightNow) / 60
    set end of output to "END_OF_DAY: " & minsToEnd & "m until 6pm"
  else
    set end of output to "END_OF_DAY: past 6pm"
  end if

  -- All remaining events
  repeat with evt in allEvents
    set end of output to "EVENT: " & (evtTitle of evt) & " @ " & (evtStart of evt as string)
  end repeat

  return output
end tell
