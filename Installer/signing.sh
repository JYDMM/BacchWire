# Names, signing and notarization shared by create_installer.sh and create_uninstaller.sh.
# Every setting can be overridden from the environment.

driverName="BACCH Router"   # Shown in Audio MIDI Setup, the bundle name and the installer
driverID="BACCHRouter"      # Used where spaces are not allowed (bundle IDs)
bundleIDPrefix="audio.TAP"
devTeamID="${DEV_TEAM_ID:-AYM3TY69AP}"
installerIdentity="${INSTALLER_IDENTITY-Developer ID Installer}" # Empty string = unsigned .pkg
notarize="${NOTARIZE:-true}"
notarizeProfile="${NOTARIZE_PROFILE:-notarize}"
channelVariants="${CHANNELS:-2 16}"

# Resolve a signing identity to exactly one certificate (preferring this team's), so a partial
# name like "Developer ID Application" can't silently pick the wrong one.
resolve_identity() { # $1 = name or SHA-1 hash, $2 = security policy args
    local matches
    if [[ "$1" =~ ^[0-9A-Fa-f]{40}$ ]]; then
        echo "$1"
        return
    fi
    matches=$(security find-identity -v $2 | grep "\"$1" | grep "($devTeamID)\"" || true)
    if [ -z "$matches" ]; then
        matches=$(security find-identity -v $2 | grep "\"$1" || true)
    fi
    if [ "$(printf '%s\n' "$matches" | grep -c .)" -ne 1 ]; then
        echo "❌ Expected exactly one \"$1\" signing identity for team $devTeamID, found:" >&2
        printf '%s\n' "${matches:-  (none)}" >&2
        echo "   Add the certificate in Xcode > Settings > Apple Accounts > Manage Certificates," >&2
        echo "   or set APP_IDENTITY / INSTALLER_IDENTITY to the certificate's SHA-1 hash." >&2
        exit 1
    fi
    printf '%s\n' "$matches" | awk '{print $2}'
}

installerSignArgs=()
pkgSuffix=""
if [ -n "$installerIdentity" ]; then
    installerIdentityHash=$(resolve_identity "$installerIdentity" "")
    installerSignArgs=(--sign "$installerIdentityHash")
else
    echo "⚠️  INSTALLER_IDENTITY is empty: the packages will NOT be signed."
    pkgSuffix="-UNSIGNED"
    notarize=false
fi

notarize_and_staple() { # $1 = package path
    if [ "$notarize" = true ]; then
        xcrun \
          notarytool submit "$1" \
          --progress \
          --wait \
          --keychain-profile "$notarizeProfile"

        xcrun stapler staple "$1"
    fi
}
