-- Create and maintain attentional transition blocks around focus-intensive meetings
-- Purpose: surface from deep work before a meeting; land after before going back under
-- Blocks are always FREE (invisible to others) — for self-organization only
--
-- 10 min "↑ surface" before the meeting
-- 10 min "↓ land" after the meeting
--
-- Applies to all meetings EXCEPT: Standup, Lunch
-- Calendar names discovered from environment, not hardcoded

set transitionMarker to "EA transition block"
set beforeMins to 10
set afterMins to 10
set weeksAhead to 2
-- Standup skipped (too short/routine to need transition)
-- Lunch skipped (handled separately by lunch hold logic below)
set skipTitles to {"Standup", "Lunch"}

-- Discover calendar names from environment or Calendar.app accounts
set personalCal to (do shell script "echo ${EA_PERSONAL_CAL:-Me}")
set workCal to (do shell script "echo ${EA_WORK_CAL:-}")
if workCal is "" then
  tell application "Calendar"
    repeat with acct in every account
      if kind of acct is CalDAV then
        set calList to every calendar of acct
        if (count of calList) > 0 then
          set workCal to name of (item 1 of calList)
          exit repeat
        end if
      end if
    end repeat
  end tell
end if
set calendarNames to {personalCal, workCal}

-- Lunch window: if no lunch event exists on a weekday, create a 45min free hold at noon
-- This ensures eating + dog walk happens even on busy days
set lunchMarker to "EA lunch hold"
set lunchDurationMins to 45

-- All-day events are excluded (no transition needed)

on titleContainsSkip(t, skipList)
  repeat with s in skipList
    if t contains s then return true
  end repeat
  return false
end titleContainsSkip

on ensureTransitionBlock(cal, blockStart, blockEnd, blockTitle, marker)
  tell application "Calendar"
    set existing to (every event of cal whose ¬
      start date is blockStart and ¬
      notes contains marker)
    if (count of existing) is 0 then
      set newBlock to make new event at end of events of cal
      set summary of newBlock to blockTitle
      set start date of newBlock to blockStart
      set end date of newBlock to blockEnd
      set notes of newBlock to marker
      set availability of newBlock to free
    end if
  end tell
end ensureTransitionBlock

on removeStaleBlocks(cal, marker, now, futureDate)
  -- Remove transition blocks whose parent meeting no longer exists
  tell application "Calendar"
    set blocks to (every event of cal whose ¬
      start date >= now and ¬
      start date <= futureDate and ¬
      notes contains marker)
    repeat with blk in blocks
      -- Stale detection: a "↑ surface" block should have a meeting starting afterMins later
      -- A "↓ land" block should have a meeting ending beforeMins earlier
      -- Simple approach: delete and recreate on each run (idempotent)
      delete blk
    end repeat
  end tell
end removeStaleBlocks

tell application "Calendar"
  set now to current date
  set futureDate to now + (weeksAhead * weeks)

  repeat with calName in calendarNames
    set cal to calendar calName

    -- Clear existing transition blocks in window (idempotent — recreate fresh each run)
    set existingBlocks to (every event of cal whose ¬
      start date >= now and ¬
      start date <= futureDate and ¬
      notes contains transitionMarker)
    repeat with blk in existingBlocks
      delete blk
    end repeat

    -- Find focus-intensive meetings
    set meetings to (every event of cal whose ¬
      start date >= now and ¬
      start date <= futureDate and ¬
      allday event is false and ¬
      status is not cancelled and ¬
      (notes is missing value or notes does not contain transitionMarker))

    repeat with mtg in meetings
      set mtgTitle to summary of mtg
      set mtgStart to start date of mtg
      set mtgEnd to end date of mtg

      -- Skip if in the skip list
      if not my titleContainsSkip(mtgTitle, skipTitles) then
        -- "↑ surface" block: beforeMins before meeting
        set beforeStart to mtgStart - (beforeMins * minutes)
        set beforeEnd to mtgStart
        my ensureTransitionBlock(cal, beforeStart, beforeEnd, "↑ surface", transitionMarker)

        -- "↓ land" block: afterMins after meeting
        set afterStart to mtgEnd
        set afterEnd to mtgEnd + (afterMins * minutes)
        my ensureTransitionBlock(cal, afterStart, afterEnd, "↓ land", transitionMarker)
      end if
    end repeat

    -- Lunch hold: opportunistically find a gap in 11am-2pm window and protect it
    -- Does NOT anchor to noon — floats to wherever there's natural breathing room
    -- Skips weekends and days that already have a real Lunch event or EA lunch hold
    repeat with dayOffset from 0 to (weeksAhead * 7)
      set checkDay to now + (dayOffset * days)
      set dow to weekday of checkDay
      if dow is not Saturday and dow is not Sunday then
        set dayStart to checkDay - (time of checkDay)

        set lunchWindowStart to dayStart + (11 * hours)
        set lunchWindowEnd to dayStart + (14 * hours)

        -- Check if a real lunch event or existing hold already covers the window
        set existingLunch to (every event of cal whose ¬
          start date >= lunchWindowStart and ¬
          start date < lunchWindowEnd and ¬
          (summary contains "Lunch" or notes contains lunchMarker))

        if (count of existingLunch) is 0 then
          -- Find the first gap of at least lunchDurationMins in the window
          -- Collect all events in the window, sorted by start time
          set windowEvents to (every event of cal whose ¬
            start date >= lunchWindowStart and ¬
            start date < lunchWindowEnd and ¬
            allday event is false and ¬
            status is not cancelled)

          -- Find gap: try each 15-min slot from 11am to 2pm-(lunchDuration)
          set foundGap to false
          set slotStart to lunchWindowStart
          set slotEnd to slotStart + (lunchDurationMins * minutes)

          repeat while slotEnd <= lunchWindowEnd and not foundGap
            -- Check if this slot is clear
            set conflicts to (every event of cal whose ¬
              start date < slotEnd and ¬
              end date > slotStart and ¬
              allday event is false and ¬
              status is not cancelled and ¬
              notes does not contain lunchMarker and ¬
              notes does not contain transitionMarker)

            if (count of conflicts) is 0 then
              -- Found a clear slot — place lunch hold here
              set lunchHold to make new event at end of events of cal
              set summary of lunchHold to "🥗 lunch + 🐕 walk"
              set start date of lunchHold to slotStart
              set end date of lunchHold to slotEnd
              set notes of lunchHold to lunchMarker
              set availability of lunchHold to free
              set foundGap to true
            else
              -- Advance by 15 minutes and try again
              set slotStart to slotStart + (15 * minutes)
              set slotEnd to slotStart + (lunchDurationMins * minutes)
            end if
          end repeat

          -- If no gap found, don't create a hold — day is too packed, iMessage instead
          if not foundGap then
            do shell script "~/.config/opencode/skill/attention/ea/imessage.sh '⚠️ No lunch gap found on " & (dayStart as string) & " — consider declining something'"
          end if
        end if
      end if
    end repeat
  end repeat
end tell
