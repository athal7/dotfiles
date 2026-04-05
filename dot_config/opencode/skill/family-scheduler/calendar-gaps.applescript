-- Returns weekend days and weekday evenings (5pm-9pm) that have no calendar events
-- in the next 14 days — these are the open gaps suitable for family activities
-- Usage: osascript calendar-gaps.applescript
-- Output: one line per open slot, e.g. "OPEN: Sat Jun 7 (all day)" or "OPEN: Fri Jun 6 evening"

tell application "Calendar"
  set rightNow to current date
  set openSlots to {}

  repeat with offset from 0 to 13
    set checkDate to rightNow + (offset * days)

    -- Normalise to midnight
    set slotStart to checkDate - (time of checkDate)

    -- Weekday number: 1=Sun, 2=Mon ... 7=Sat
    set dow to weekday of slotStart

    -- Weekend = Saturday (7) or Sunday (1)
    set isWeekend to (dow = Saturday or dow = Sunday)
    -- Weekday evening = Mon-Fri 5pm-9pm
    set isWeekday to not isWeekend

    -- Build the window to check
    if isWeekend then
      set windowStart to slotStart + (9 * hours)   -- 9am
      set windowEnd to slotStart + (21 * hours)    -- 9pm
      set label to (weekday of slotStart as string) & " " & (slotStart as string)
    else
      set windowStart to slotStart + (17 * hours)  -- 5pm
      set windowEnd to slotStart + (21 * hours)    -- 9pm
      set label to (weekday of slotStart as string) & " " & (slotStart as string) & " evening"
    end if

    -- Check all calendars for events in this window
    set busy to false
    repeat with cal in every calendar
      set evts to (every event of cal whose start date >= windowStart and start date < windowEnd)
      if (count of evts) > 0 then
        set busy to true
        exit repeat
      end if
    end repeat

    if not busy then
      set end of openSlots to "OPEN: " & label
    end if
  end repeat

  return openSlots
end tell
