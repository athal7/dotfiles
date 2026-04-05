-- Returns today's past and remaining calendar events, plus time windows
-- Output includes:
--   DAY_OF_WEEK: Monday
--   PAST_EVENT: <title> @ <time>  (one per completed event today)
--   PAST_COUNT: N events completed today
--   NEXT_EVENT: <title> @ <time> (in Xm)
--   GAP: Xm until next event  (or "rest of day free" if none)
--   END_OF_DAY: Xm until 6pm (or "past 6pm")
--   EVENT: <title> @ <time>  (one line per remaining event)
-- Usage: osascript calendar-today.applescript
tell application "Calendar"
  set rightNow to current date
  set startOfDay to rightNow - (time of rightNow)
  set endOfDay to startOfDay + (23 * hours) + (59 * minutes)
  set workDayEnd to startOfDay + (18 * hours) -- 6pm

  -- Day of week
  set dowNames to {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
  set dowIndex to (weekday of rightNow) as integer
  set dayName to item dowIndex of dowNames

  -- Collect past events today (already ended)
  set pastEvents to {}
  repeat with cal in every calendar
    set evts to (every event of cal whose start date >= startOfDay and end date <= rightNow)
    repeat with evt in evts
      set end of pastEvents to {evtTitle:summary of evt, evtStart:start date of evt}
    end repeat
  end repeat

  -- Collect remaining events today
  set allEvents to {}
  repeat with cal in every calendar
    set evts to (every event of cal whose start date >= rightNow and start date <= endOfDay)
    repeat with evt in evts
      set end of allEvents to {evtTitle:summary of evt, evtStart:start date of evt}
    end repeat
  end repeat

  -- Sort remaining by start time (bubble sort — small lists)
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

  -- Day of week
  set end of output to "DAY_OF_WEEK: " & dayName

  -- Past events
  set pastCount to count of pastEvents
  repeat with evt in pastEvents
    set end of output to "PAST_EVENT: " & (evtTitle of evt) & " @ " & (evtStart of evt as string)
  end repeat
  set end of output to "PAST_COUNT: " & pastCount & " events completed today"

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

  -- Remaining events
  repeat with evt in allEvents
    set end of output to "EVENT: " & (evtTitle of evt) & " @ " & (evtStart of evt as string)
  end repeat

  return output
end tell
