tell application "Google Chrome"
	if not (exists window 1) then return
	set theURL to URL of active tab of window 1
	-- bail if current tab is blank
	if not {theURL starts with "http"} then return
	close active tab of window 1
end tell

tell application "Safari"
	if not (exists window 1) then
		reopen
	else
		tell window 1 to set current tab to (make new tab)
	end if
	set URL of current tab of window 1 to theURL
	activate
end tell
