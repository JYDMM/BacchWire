# Appended to each variant's generated postinstall, which sets $driverPath.
#
# Asks the logged-in user before restarting coreaudiod, which loads the new driver without a
# system restart. launchd brings coreaudiod straight back.
#   - Not Now, or no answer within 5 minutes: audio is left alone and the driver loads at the
#     next system restart.
#   - Nobody logged in, or the dialog can't be shown: restart anyway, since the driver wouldn't
#     load otherwise and the installer's welcome screen has already warned about it.
# Nothing here may fail the install.

consoleUser=$(stat -f%Su /dev/console)
answer=""

case "$consoleUser" in
    ""|root|loginwindow)
        ;;
    *)
        answer=$(launchctl asuser "$(id -u "$consoleUser")" sudo -u "$consoleUser" osascript \
            -e 'activate' \
            -e 'set theMessage to "BACCH Router needs to restart the macOS audio service to finish installing." & return & return & "Audio will stop for a moment in all applications. Save your work in any audio applications, then click Restart Audio."' \
            -e "set theIcon to POSIX file \"$driverPath/Contents/Resources/BlackHole.icns\" as alias" \
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
