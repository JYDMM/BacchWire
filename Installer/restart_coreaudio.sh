# Appended to the generated postinstall of each installer and uninstaller, which sets $driverPath
# and $restartAction.
#
# Asks the logged-in user before restarting coreaudiod, which applies the change without a system
# restart. launchd brings coreaudiod straight back.
#   - Not Now, or no answer within 5 minutes: audio is left alone and the change applies at the
#     next system restart.
#   - Nobody logged in, or the dialog can't be shown: restart anyway, since the change wouldn't
#     apply otherwise and the installer's welcome screen has already warned about it.
# Nothing here may fail the install.

consoleUser=$(stat -f%Su /dev/console)
answer=""

# The uninstaller has already removed the driver, and the logo with it.
iconPath="$driverPath/Contents/Resources/BlackHole.icns"
if [ -f "$iconPath" ]; then
    dialogIcon="POSIX file \"$iconPath\" as alias"
else
    dialogIcon="note"
fi

case "$consoleUser" in
    ""|root|loginwindow)
        ;;
    *)
        answer=$(launchctl asuser "$(id -u "$consoleUser")" sudo -u "$consoleUser" osascript \
            -e 'activate' \
            -e "set theMessage to \"BACCH Router needs to restart the macOS audio service to $restartAction.\" & return & return & \"Audio will stop for a moment in all applications. Save your work in any audio applications, then click Restart Audio.\"" \
            -e "set theIcon to $dialogIcon" \
            -e 'display dialog theMessage with title "BACCH Router" buttons {"Not Now", "Restart Audio"} default button "Restart Audio" with icon theIcon giving up after 300')
        ;;
esac

case "$answer" in
    *"button returned:Not Now"*|*"gave up:true"*)
        ;;
    *)
        killall -9 coreaudiod || true
        ;;
esac

exit 0
