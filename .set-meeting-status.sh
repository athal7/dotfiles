#!/bin/zsh

function setStatus {
  osascript -e "
display dialog \"Set Slack Status?\"

activate application \"Slack\"

tell application \"System Events\"
  keystroke \"k\" using command down
  keystroke \"$(whoami)\"
  keystroke return

  set textToType to \"/status $1\"
  keystroke textToType
  keystroke return
end tell
"
}

eventsNow=$(/usr/local/bin/icalBuddy -ic athal@2u.com -ea eventsNow)
statusFile="/tmp/event-now"
now=$(date +%d.%m.%y-%H:%M:%S)

if [[ $eventsNow ]]; then
  echo "$now In a meeting"
  if [ ! -e "$statusFile" ]; then
    echo "Setting status"
    setStatus ":meeting:"
    touch $statusFile
  fi
else
  echo "$now Free"
  if [ -e "$statusFile" ]; then
    setStatus "clear"
    rm $statusFile
  fi
fi
