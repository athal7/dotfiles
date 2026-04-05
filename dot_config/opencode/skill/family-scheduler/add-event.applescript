-- Adds an event to the 105 calendar
-- Usage: osascript add-event.applescript "TITLE" "YYYY-MM-DD HH:MM" "YYYY-MM-DD HH:MM" "URL"
on run argv
  set eventTitle to item 1 of argv
  set startStr to item 2 of argv
  set endStr to item 3 of argv
  set eventURL to item 4 of argv

  tell application "Calendar"
    set cal105 to calendar "105"
    set newEvent to make new event at end of events of cal105
    set summary of newEvent to eventTitle
    set start date of newEvent to date startStr
    set end date of newEvent to date endStr
    if eventURL is not "" then
      set url of newEvent to eventURL
    end if
  end tell
end run
