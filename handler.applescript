-- handler.applescript
-- macOS delivers magnet: clicks to this app as a GURL Apple Event, which lands
-- in `on open location`. We run send-magnet.sh (bundled inside this app, so the
-- app is self-contained) and post its one-line result as a notification HERE,
-- inside the app — that's what makes the notification carry Magnetize's icon.

on open location this_URL
	set scriptPath to POSIX path of (path to resource "send-magnet.sh")
	set theMsg to do shell script quoted form of scriptPath & " " & quoted form of this_URL
	if theMsg is not "" then
		display notification theMsg with title "Magnetize"
	end if
end open location
