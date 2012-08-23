tell application "System Events"
  tell current location of network preferences
    set VPNservice to service "LSVPN"
    if exists VPNservice then connect VPNservice
  end tell
end tell
