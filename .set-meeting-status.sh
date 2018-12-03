#!/bin/zsh

script="
display dialog \"Set Slack meeting status?\"

activate application \"Slack\"

tell application \"System Events\"
	set textToType to \"/status :meeting:\"
	keystroke textToType
	keystroke return
end tell
"

eventsNow=$(/usr/local/bin/icalBuddy -ic athal@2u.com -ea eventsNow)
statusFile="/tmp/event-now"
now=$(date +%d.%m.%y-%H:%M:%S)

if [[ $eventsNow ]]; then
  echo "$now In a meeting"
  if [ ! -e "$statusFile" ]; then
    echo "Setting status"
    osascript -e $script
    touch $statusFile
  fi
else
  echo "$now Free"
  if [ -e "$statusFile" ]; then
    rm $statusFile
  fi
fi
